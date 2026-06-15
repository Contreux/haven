# Haven — Milestone 5: Onboarding + Paywall (Design Spec)

**Date:** 2026-06-15
**Status:** Approved for planning (standing authorization)
**Milestone:** 5 of 5 (final)

---

## 1. Goal

The first-run experience: a calm, clinical **onboarding** that calibrates the app to the user (11 questions → a synthesized profile), requests the **location** + **reminder** permissions that make Haven work, and presents the **paywall** (StoreKit 2). After onboarding the user lands in the main app (M1–M4). This is what a new user sees before they ever reach Today.

### Non-goals / deferred
**Real accounts / multi-device auth** (Sign in with Apple, data migration) — explicitly deferred to a focused follow-up (user decision). The "I already have an account" link is present but wired later. Real App Store Connect products (M5 uses a local StoreKit test config; real products are a launch step).

---

## 2. Confirmed decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Auth | **Deferred.** Onboarding + paywall run on the existing device identity. |
| 2 | Paywall testing | **Local `.storekit` config** — purchases work in the simulator with NO App Store Connect. Real products at launch. |
| 3 | Plans | **Yearly** ($83.20/yr, 7-day free trial) + **Weekly** ($12/wk), matching the prototype. StoreKit 2 `Product`/`Transaction`. |
| 4 | Validation | A Convex action records/validates the StoreKit transaction (server-side entitlement record). |
| 5 | Persistence | Extend `settings`: `onboarded: bool`, `answers: object`, `reminderTime?: string`, `lat?/lon?: number`, `subscribed: bool`. Synced via Convex. |
| 6 | Permissions | Real **CoreLocation** (When-In-Use) → sets `store.location`; real **UNUserNotificationCenter** daily reminder at the chosen time. Both skippable. |
| 7 | Profile synth | `buildProfile(answers)` is a **pure HavenCore function** (klass + suspected chips + watch list), tested. |
| 8 | Gate | `RootView`: if not onboarded → `OnboardingFlow`; else `RootTabView`. |

---

## 3. Architecture

```
RootView ── settings.onboarded? ──► RootTabView (M1–M4)
              │ no
              ▼
        OnboardingFlow (step machine)
        Welcome → Q1…Q11 → Synthesis → PermWeather → PermReminders → Paywall → Done
              │ writes answers/reminder/location to Convex settings; requests permissions
              ▼ completeOnboarding(subscribed) → settings.onboarded = true → app

StoreKit: PaywallScreen → StoreService (Product.products / purchase) → Transaction
          → validateSubscription Convex action → settings.subscribed = true
```

`OnboardingFlow` is a SwiftUI step machine holding `answers: [String: …]`. `buildProfile` (HavenCore, pure) drives Synthesis. `StoreService` (app, StoreKit 2) loads products from the `.storekit` config and purchases. Permissions use the iOS frameworks behind small wrappers.

---

## 4. Backend — Convex

Extend `settings` (`schema.ts`) + `convex/settings.ts`:
```ts
settings: { userId, theme, onboarded?: boolean, answers?: any(v.optional(v.object/string)),
            reminderTime?: string, lat?: number, lon?: number, subscribed?: boolean }
```
- mutation `completeOnboarding({ userId, answers, reminderTime?, lat?, lon? })` → upsert settings with `onboarded: true` + the fields.
- mutation `setSubscribed({ userId, subscribed })`.
- query `getSettings` → already exists; extend to return the new fields (default `onboarded:false`, `subscribed:false`).
- action `validateSubscription({ userId, transactionId })` → (M5: record-only; real receipt validation against Apple is a launch step) sets `subscribed: true`.

`answers` stored as a JSON object (or a JSON string to keep the validator simple — store `v.optional(v.string())` and encode/decode JSON client-side).

## 5. HavenCore — profile + onboarding model

`OnboardingQuestion` (id, kind single/multi, layout list/grid, kicker, title, sub, options[(value,label,icon?)], requiresSex?, notSure?) + the `questions: [OnboardingQuestion]` catalog (the 11 from the prototype). `buildProfile(answers: [String: [String]]) -> Profile` where `Profile { klass: String, suspected: [String], watch: [(icon,title,sub)] }` (ported from `buildProfile`). All pure + tested. `Settings` model extended with the new fields (Codable, optional, back-compat).

`TodayStore`/a small `OnboardingStore` holds answers and exposes `profile`. Persistence via a `DayDataSource.completeOnboarding(...)` + `getSettings` (the store already reads settings; extend).

## 6. Client — onboarding screens

All tokenized, matching the prototype `onboarding.jsx`:
- **WelcomeScreen** — flame mark, big serif headline, sub, "Get started" + "I already have an account" (the latter present, no-op/deferred).
- **QuestionScreen** — progress segments + back, kicker/title/sub, `ListOption` rows or `GridChip` grid (single select highlights one; multi toggles; optional "not sure"), Next (enabled when answered). Conditional skip (the cycle question only if sex female/intersex).
- **SynthesisScreen** — "Building your profile" with cycling lines (~2.5s) → reveal card (profile klass, suspected chips, "what Haven will watch" rows), "Looks right".
- **PermWeatherScreen** — cloud tile, copy, "Enable location" (requests CoreLocation → store.location) / "Not now".
- **PermRemindersScreen** — bell tile, copy, 4 time options, "Turn on reminders" (requests notifications + schedules) / "Maybe later".
- **PaywallScreen** — flame, title/sub, 4 feature rows, yearly/weekly plan selector (yearly default, "SAVE 87% · 7 DAYS FREE" badge), CTA ("Start 7-day free trial" / "Subscribe weekly"), fine print, Restore/Terms/Privacy links, close (×).
- **DoneScreen** — check mark, "You're all set", trial/profile sub, "Enter Haven".

`OnboardingFlow` sequences these and writes to Convex at the end (or incrementally), then flips `onboarded`.

## 7. StoreKit

- A `Haven/Haven.storekit` config (committed) defining two auto-renewable subscriptions in one group: `haven.yearly` (with a 7-day intro free trial) + `haven.weekly`. project.yml references it as the scheme's StoreKit config.
- `StoreService` (app): `Product.products(for:)` to load, `product.purchase()` → verify `Transaction` → call `validateSubscription` → `setSubscribed(true)`. `Transaction.currentEntitlements` to restore.
- Paywall reads loaded products for prices (fallback to the prototype's static copy if products fail to load in CI).

## 8. Testing strategy

| Layer | Test |
|---|---|
| Convex | `completeOnboarding`/`setSubscribed` upsert; `getSettings` defaults (onboarded false). |
| HavenCore | `buildProfile` (episodic/chronic, aura, suspected chips, cycle watch); question catalog count + conditional; Settings decode back-compat. |
| UI (Maestro) | fresh launch → Welcome → answer through to Paywall → (StoreKit test) subscribe → Done → Today. Gate: relaunch skips onboarding. |
| Fidelity | Welcome / a QuestionScreen / Synthesis / Paywall vs the prototype. |

## 9. Definition of done
1. Fresh install shows onboarding; completing it (answers + permissions + a StoreKit test purchase) lands in Today; relaunch goes straight to Today (gate persists via Convex settings).
2. `buildProfile` produces the right profile from answers.
3. Paywall loads the two plans from the `.storekit` config and a test purchase succeeds + records `subscribed`.
4. All suites pass; guard clean; app builds; Maestro green; screens match the prototype.

## 10. Open risks
- **StoreKit in CI/Maestro** — the `.storekit` config enables simulator purchases; Maestro must tap through the StoreKit purchase sheet (Apple's system sheet — may need the StoreKit testing "Ask to Buy off" + the sheet's "Subscribe"/"Confirm" buttons). Fallback: verify the paywall renders + plan selection; the purchase sheet is system UI.
- **Permission prompts in Maestro** — location/notification system dialogs; the flow allows "skip", so Maestro can skip them.
- **Onboarding gate via Convex** — `getSettings.onboarded` drives the gate; on a fresh sim (DEBUG `sim-device`) it may already be onboarded from a prior run — reset by clearing settings or use a fresh device id for the test.
- **answers JSON** — stored as a JSON string in settings to keep the Convex validator simple; client encodes/decodes.
