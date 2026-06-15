# Haven M5 · Plan 2 — Paywall (StoreKit) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The StoreKit 2 paywall — yearly (7-day trial) + weekly plans loaded from a local `.storekit` config (simulator-purchasable, no App Store Connect), inserted into the onboarding flow before Done, recording `subscribed` in Convex.

**Architecture:** A committed `Haven/Haven.storekit` config defines two subscriptions; the scheme references it. `StoreService` (StoreKit 2) loads products + purchases; `PaywallScreen` (tokenized, per prototype) selects a plan + buys; on success → `setSubscribed(true)`. The onboarding flow shows the paywall after permissions.

**Tech Stack:** StoreKit 2 · Swift 6 / SwiftUI · Convex · XcodeGen.

**Reference:** spec §7; M5-P1 (OnboardingFlow, settings); handoff `onboarding.jsx` Paywall.

---

## Task 1: StoreKit config + scheme wiring

**Files:** Create `Haven/Haven.storekit`; Modify `Haven/project.yml`.

- [ ] **Step 1: Write `Haven/Haven.storekit`** — a StoreKit configuration with one subscription group "Haven Premium" containing two auto-renewable subscriptions:
```json
{
  "identifier" : "HAVEN_SK",
  "nonRenewingSubscriptions" : [],
  "products" : [],
  "settings" : { "_applicationInternalID" : "haven", "_developerTeamID" : "" },
  "subscriptionGroups" : [
    {
      "id" : "HAVEN_PREMIUM",
      "localizationsAndOffers" : [],
      "name" : "Haven Premium",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "83.20",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "HAVEN_YEARLY",
          "introductoryOffer" : {
            "internalID" : "HAVEN_TRIAL",
            "paymentMode" : "free",
            "subscriptionPeriod" : "P1W"
          },
          "localizations" : [ { "description" : "Full access, billed yearly", "displayName" : "Yearly", "locale" : "en_US" } ],
          "productID" : "haven.yearly",
          "recurringSubscriptionPeriod" : "P1Y",
          "referenceName" : "Yearly",
          "subscriptionGroupID" : "HAVEN_PREMIUM",
          "type" : "RecurringSubscription"
        },
        {
          "adHocOffers" : [], "codeOffers" : [],
          "displayPrice" : "12.00", "familyShareable" : false, "groupNumber" : 1,
          "internalID" : "HAVEN_WEEKLY",
          "localizations" : [ { "description" : "Full access, billed weekly", "displayName" : "Weekly", "locale" : "en_US" } ],
          "productID" : "haven.weekly",
          "recurringSubscriptionPeriod" : "P1W",
          "referenceName" : "Weekly",
          "subscriptionGroupID" : "HAVEN_PREMIUM",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : { "major" : 3, "minor" : 0 }
}
```
> If Xcode rejects the hand-written JSON shape, the canonical fix is to create the config in Xcode once; but this shape matches Xcode 15/16's `.storekit` format. Keep `productID`s `haven.yearly` / `haven.weekly`.

- [ ] **Step 2: Reference it in `Haven/project.yml`** — add a scheme with the StoreKit config so the simulator uses it. Under the `Haven` target add a `scheme:` (XcodeGen target-level scheme) or a top-level `schemes:`:
```yaml
schemes:
  Haven:
    build:
      targets: { Haven: all }
    run:
      config: Debug
      storeKitConfiguration: Haven.storekit
```
(Place `Haven.storekit` at `Haven/Haven.storekit`; XcodeGen resolves it relative to the project. Also add it to the target's `sources` so it's bundled/known: under `targets.Haven.sources` include `[Sources, Haven.storekit]`.)

- [ ] **Step 3: Generate + build** — `cd Haven && xcodegen generate && cd .. && xcodebuild ... build` → SUCCEEDED. (The `.storekit` file is config, not code; guard unaffected.)
- [ ] **Step 4: Commit** — `git add Haven/Haven.storekit Haven/project.yml && git commit -m "feat: add StoreKit config with yearly/weekly subscriptions"`

---

## Task 2: `StoreService`

**Files:** Create `Haven/Sources/Paywall/StoreService.swift`.

- [ ] **Step 1: Write it** (StoreKit 2 load + purchase + entitlement)
```swift
import Foundation
import StoreKit

@MainActor
@Observable
final class StoreService {
    static let productIDs = ["haven.yearly", "haven.weekly"]
    private(set) var products: [Product] = []
    private(set) var purchasing = false

    func load() async {
        products = (try? await Product.products(for: Self.productIDs)) ?? []
        products.sort { $0.id < $1.id }   // weekly < yearly alphabetically? ensure stable; reorder in UI
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// Returns the transaction id on success, nil on cancel/failure.
    func purchase(_ id: String) async -> String? {
        guard let product = product(id) else { return nil }
        purchasing = true; defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    return String(transaction.id)
                }
                return nil
            default: return nil
            }
        } catch { return nil }
    }

    func hasEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified = result { return true }
        }
        return false
    }
}
```

- [ ] **Step 2: Build → SUCCEEDED, guard → pass. Commit** — `git add Haven/Sources/Paywall/StoreService.swift && git commit -m "feat: add StoreKit 2 StoreService"`

---

## Task 3: `PaywallScreen`

**Files:** Create `Haven/Sources/Paywall/PaywallScreen.swift`.

- [ ] **Step 1: Write it** (tokenized, per prototype; uses StoreService for prices with static fallback)
```swift
import SwiftUI
import StoreKit
import HavenDesignSystem

struct PaywallScreen: View {
    @Environment(\.theme) private var theme
    let store: StoreService
    let onSubscribe: (String) -> Void   // productID
    let onClose: () -> Void

    @State private var plan = "haven.yearly"
    private let feats = [
        ("sparkles", "AI trigger analysis on every meal you log"),
        ("cloud", "Barometric weather-risk forecasts"),
        ("book", "Unlimited history & doctor-ready reports"),
        ("chart.line.uptrend.xyaxis", "Personal pattern insights that sharpen over time"),
    ]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                HStack { Spacer(); Button(action: onClose) { Image(systemName: "xmark").foregroundStyle(theme.inkSoft) } }
                Image(systemName: "flame.fill").imageScale(.large).foregroundStyle(theme.accent)
                Text("Start finding your triggers").havenText(.screenTitle, color: theme.ink)
                Text("Your profile's ready. Unlock the tools that turn daily logs into real answers.").havenText(.body, color: theme.inkSoft)
                ForEach(feats, id: \.1) { icon, t in
                    HStack(spacing: Spacing.s3) { Image(systemName: icon).foregroundStyle(theme.accent); Text(t).havenText(.body, color: theme.ink) }
                }
                planRow("haven.yearly", name: "Yearly", meta: "$83.20 billed once a year", price: "$1.60", unit: "per week", badge: "SAVE 87% · 7 DAYS FREE")
                planRow("haven.weekly", name: "Weekly", meta: "Billed every week", price: "$12", unit: "per week", badge: nil)
                Spacer()
                Button { onSubscribe(plan) } label: {
                    Text(plan == "haven.yearly" ? "Start 7-day free trial" : "Subscribe weekly")
                        .havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }.accessibilityIdentifier("pay-subscribe")
                Text(plan == "haven.yearly" ? "7 days free, then $83.20/year. Cancel anytime." : "$12 per week. Cancel anytime.")
                    .havenText(.meta, color: theme.inkFaint)
            }.padding(Spacing.s7)
        }
        .task { await store.load() }
    }

    private func planRow(_ id: String, name: String, meta: String, price: String, unit: String, badge: String?) -> some View {
        let on = plan == id
        let displayPrice = store.product(id)?.displayPrice ?? price
        return Button { plan = id } label: {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                if let badge { Text(badge).havenText(.eyebrow, color: theme.accent) }
                HStack {
                    VStack(alignment: .leading) {
                        Text(name).havenText(.sectionHead, color: theme.ink)
                        Text(meta).havenText(.meta, color: theme.inkSoft)
                    }
                    Spacer()
                    Text(displayPrice).havenText(.sectionHead, color: theme.ink)
                }
            }
            .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(on ? theme.accent : theme.hairline, lineWidth: on ? 2 : 1))
        }
        .accessibilityIdentifier("plan-\(id)")
    }
}
```

- [ ] **Step 2: Build → SUCCEEDED, guard → pass. Commit** — `git add Haven/Sources/Paywall/PaywallScreen.swift && git commit -m "feat: add PaywallScreen"`

---

## Task 4: `validateSubscription` action + insert paywall into the flow

**Files:** Create `convex/billing.ts` + test; Modify `Haven/Sources/Onboarding/OnboardingFlow.swift`, `Haven/Sources/Services/ConvexService.swift` (already has setSubscribed from M5-P1).

- [ ] **Step 1: `convex/billing.ts`** (M5: record-only; real Apple receipt validation is a launch step)
```typescript
import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";

export const validateSubscription = action({
  args: { userId: v.string(), transactionId: v.string() },
  handler: async (ctx, { userId, transactionId }) => {
    // M5: trust the client-verified StoreKit 2 transaction and record entitlement.
    // Launch step: verify `transactionId` against Apple's verifyReceipt / App Store Server API.
    await ctx.runMutation(api.settings.setSubscribed, { userId, subscribed: true });
    return { ok: true };
  },
});
```
Test `convex/billing.test.ts`:
```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";
const modules = import.meta.glob("./**/*.ts");
test("validateSubscription marks the user subscribed", async () => {
  const t = convexTest(schema, modules);
  await t.action(api.billing.validateSubscription, { userId: "dev-1", transactionId: "tx-1" });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.subscribed).toBe(true);
});
```

- [ ] **Step 2: Run → PASS** (`npx vitest run convex/billing.test.ts`), `npm test`. Commit — `git add convex/billing.ts convex/billing.test.ts && git commit -m "feat: add validateSubscription action"`. Deploy (`npx convex dev --once`).

- [ ] **Step 3: Add `validateSubscription` to `DayDataSource` + `ConvexService`**:
```swift
// DayDataSource:
    func validateSubscription(transactionId: String) async throws
// ConvexService:
    func validateSubscription(transactionId: String) async throws {
        try await client.action("billing:validateSubscription", with: ["userId": userId, "transactionId": transactionId])
    }
// FakeSource: func validateSubscription(transactionId: String) async throws {}
```

- [ ] **Step 4: Insert the paywall into `OnboardingFlow.swift`** — add a `.paywall` step between `.permReminders` and `.done`, and a `StoreService`:
  - Add `@State private var storeKit = StoreService()`.
  - Change `permReminders` onEnable/onSkip to advance to `.paywall` (instead of calling `finish()` directly).
  - Add `case .paywall: PaywallScreen(store: storeKit, onSubscribe: { id in Task { await subscribe(id) } }, onClose: { Task { await finish(subscribed: false) } })`.
  - Add `enum Step { ... case paywall ... }`.
  - `private func subscribe(_ id: String) async { if let tx = await storeKit.purchase(id) { try? await service.validateSubscription(transactionId: tx) }; await finish(subscribed: true) }`
  - Change `finish()` to `finish(subscribed: Bool)` — it still calls `completeOnboarding`; the subscribed flag is recorded by `validateSubscription` (server) so `finish` just persists onboarding + goes to `.done`.
  - The reminders step's `finish()` calls become `step = .paywall`.

- [ ] **Step 5: Build → SUCCEEDED, guard → pass. Commit** — `git add convex/_generated Haven/Sources/Onboarding/OnboardingFlow.swift Haven/Sources/Services/ConvexService.swift HavenCore/Sources/HavenCore/DayDataSource.swift HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift && git commit -m "feat: insert paywall into onboarding + wire subscription validation"`

---

## Task 5: Maestro + fidelity

**Files:** Create/extend `Haven/maestro/onboarding.yaml`.

- [ ] **Step 1: On a non-onboarded device** (per M5-P1 T7 approach), drive the flow to the paywall and screenshot it. A full purchase through Apple's StoreKit sheet is system UI; assert the paywall renders + plan selection works:
```yaml
# ... continue the onboarding flow to the paywall ...
- assertVisible: "Start finding your triggers"
- tapOn:
    id: "plan-haven.weekly"
- takeScreenshot: m5-paywall
- tapOn:
    id: "pay-subscribe"
# StoreKit purchase sheet is system UI; in the .storekit sim env it shows a Confirm — tap if present
- runFlow:
    when: { visible: "Subscribe" }
    commands:
      - tapOn: "Subscribe"
- assertVisible: "You're all set"
```
(If the system purchase sheet can't be driven, assert the paywall + screenshot, and verify `setSubscribed` separately via `npx convex run settings:getSettings`.)

- [ ] **Step 2: Run, read `m5-paywall.png`, compare to the prototype Paywall.** Reconcile gaps.
- [ ] **Step 3: Commit** — `git add Haven/maestro/onboarding.yaml && git commit -m "test: extend onboarding flow with paywall"`

---

## Definition of done (M5-P2 = M5 complete)
1. Onboarding reaches the paywall after permissions; the two plans load from the `.storekit` config; selecting + a StoreKit test purchase records `subscribed` and lands on Done → the app.
2. `validateSubscription` records entitlement; `getSettings.subscribed` reflects it.
3. All suites green; guard clean; app builds; Maestro green (paywall renders + plan select; purchase via the sim StoreKit sheet); screen matches the prototype.

## Self-review notes
- **Spec coverage:** §7 StoreKit config (T1), StoreService (T2), PaywallScreen (T3), validation action + flow insert (T4), Maestro/fidelity (T5).
- **Build continuity:** T4 grows `DayDataSource` (+validateSubscription) AND implements ConvexService + FakeSource together.
- **Risks:** (1) `.storekit` JSON shape — if Xcode can't parse, create via Xcode once; productIDs fixed. (2) StoreKit purchase sheet is system UI — Maestro may not drive the confirm; fallback asserts the paywall + verifies subscribed server-side. (3) the scheme `storeKitConfiguration` via XcodeGen — if unsupported by the XcodeGen version, set it in the generated scheme manually or via an `xcconfig`; verify the products load (empty `products` = config not wired).
