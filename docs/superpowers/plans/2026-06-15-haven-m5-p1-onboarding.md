# Haven M5 · Plan 1 — Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The first-run onboarding — Welcome → 11 calibration questions → Synthesis (profile) → location + reminder permissions → Done — persisted to Convex and gating the app on launch. (Paywall is M5-P2, inserted before Done.)

**Architecture:** Pure `buildProfile` + the question catalog in HavenCore; a SwiftUI `OnboardingFlow` step machine; Convex `settings` extended with `onboarded`/`answers`/`reminderTime`/`lat`/`lon`; `RootView` gates on `getSettings.onboarded`. Permissions via thin CoreLocation/UNUserNotificationCenter wrappers.

**Tech Stack:** Convex/convex-test · Swift 6 / SwiftUI · HavenDesignSystem · HavenCore.

**Reference:** spec `docs/superpowers/specs/2026-06-15-haven-m5-onboarding-paywall-design.md`; handoff `onboarding.jsx`.

---

## Task 1: Extend `settings` schema + mutations

**Files:** Modify `convex/schema.ts`, `convex/settings.ts`; Test `convex/settings.test.ts`.

- [ ] **Step 1: Add failing tests** (append to settings.test.ts)
```typescript
test("completeOnboarding sets onboarded + fields", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.completeOnboarding, {
    userId: "dev-1", answers: '{"frequency":"weekly"}', reminderTime: "evening", lat: 51.5, lon: -0.1,
  });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.onboarded).toBe(true);
  expect(s.reminderTime).toBe("evening");
});
test("getSettings defaults onboarded/subscribed false", async () => {
  const t = convexTest(schema, modules);
  const s = await t.query(api.settings.getSettings, { userId: "new" });
  expect(s.onboarded).toBe(false);
  expect(s.subscribed).toBe(false);
});
test("setSubscribed flips subscribed", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.setSubscribed, { userId: "dev-1", subscribed: true });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.subscribed).toBe(true);
});
```

- [ ] **Step 2: Run → FAIL** — `npx vitest run convex/settings.test.ts`.

- [ ] **Step 3: Edit `convex/schema.ts`** — extend the `settings` table:
```typescript
  settings: defineTable({
    userId: v.string(),
    theme: v.string(),
    onboarded: v.optional(v.boolean()),
    answers: v.optional(v.string()),       // JSON-encoded answers
    reminderTime: v.optional(v.string()),
    lat: v.optional(v.number()),
    lon: v.optional(v.number()),
    subscribed: v.optional(v.boolean()),
  }).index("by_user", ["userId"]),
```

- [ ] **Step 4: Edit `convex/settings.ts`** — extend `getSettings` return + add the mutations (reuse the existing upsert pattern):
```typescript
export const getSettings = query({
  args: { userId: v.string() },
  handler: async (ctx, { userId }) => {
    const row = await ctx.db.query("settings").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    return {
      theme: row?.theme ?? "dark",
      onboarded: row?.onboarded ?? false,
      answers: row?.answers ?? "",
      reminderTime: row?.reminderTime ?? "",
      lat: row?.lat ?? null,
      lon: row?.lon ?? null,
      subscribed: row?.subscribed ?? false,
    };
  },
});

async function upsertSettings(ctx: any, userId: string, patch: Record<string, unknown>) {
  const existing = await ctx.db.query("settings").withIndex("by_user", (q: any) => q.eq("userId", userId)).unique();
  if (existing) { await ctx.db.patch(existing._id, patch); return existing._id; }
  return await ctx.db.insert("settings", { userId, theme: "dark", ...patch });
}

export const completeOnboarding = mutation({
  args: { userId: v.string(), answers: v.string(), reminderTime: v.optional(v.string()), lat: v.optional(v.number()), lon: v.optional(v.number()) },
  handler: async (ctx, { userId, answers, reminderTime, lat, lon }) =>
    await upsertSettings(ctx, userId, { onboarded: true, answers, reminderTime, lat, lon }),
});

export const setSubscribed = mutation({
  args: { userId: v.string(), subscribed: v.boolean() },
  handler: async (ctx, { userId, subscribed }) => await upsertSettings(ctx, userId, { subscribed }),
});
```
> Keep the existing `updateSettings` mutation; refactor it to use `upsertSettings` if convenient (or leave it). `mutation`/`query`/`v` already imported.

- [ ] **Step 5: Run → PASS.** `npm test` → all pass.
- [ ] **Step 6: Commit** — `git add convex/schema.ts convex/settings.ts convex/settings.test.ts && git commit -m "feat: extend settings with onboarding + subscription fields"`. Deploy: `npx convex dev --once 2>&1 | tail -4` (+commit `_generated` if changed).

---

## Task 2: HavenCore — question catalog + `buildProfile`

**Files:** Create `HavenCore/Sources/HavenCore/Onboarding.swift`; Test `HavenCore/Tests/HavenCoreTests/OnboardingTests.swift`.

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import HavenCore

@Suite struct OnboardingTests {
    @Test func catalogHasElevenQuestions() {
        #expect(OnboardingCatalog.questions.count == 11)
        #expect(OnboardingCatalog.questions.first?.id == "frequency")
    }
    @Test func cycleQuestionRequiresSex() {
        let cycle = OnboardingCatalog.questions.first { $0.id == "cycle" }!
        #expect(cycle.requiresSex == ["female", "intersex"])
    }
    @Test func buildsEpisodicVsChronic() {
        #expect(buildProfile(["frequency": ["rare"]]).klass == "Episodic migraine")
        #expect(buildProfile(["frequency": ["chronic"]]).klass == "Chronic migraine")
        #expect(buildProfile(["frequency": ["weekly"], "aura": ["often"]]).klass == "Episodic migraine with aura")
    }
    @Test func suspectedChipsMapTriggers() {
        let p = buildProfile(["triggers": ["alcohol", "weather", "unsure"]])
        #expect(p.suspected.contains("Alcohol"))
        #expect(p.suspected.contains("Weather"))
        #expect(p.suspected.contains("To be discovered") == false)  // had real picks
    }
    @Test func emptyTriggersShowDiscovery() {
        #expect(buildProfile([:]).suspected == ["To be discovered"])
    }
    @Test func cycleTrackAddsHormonalWatch() {
        let p = buildProfile(["cycle": ["track"]])
        #expect(p.watch.contains { $0.title == "Hormonal cycle" })
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement `Onboarding.swift`**
```swift
import Foundation

public struct OnboardingOption: Sendable, Equatable, Identifiable {
    public let value: String; public let label: String; public let icon: String?
    public var id: String { value }
    public init(_ value: String, _ label: String, icon: String? = nil) { self.value = value; self.label = label; self.icon = icon }
}
public struct OnboardingQuestion: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable { case single, multi }
    public enum Layout: Sendable { case list, grid }
    public let id: String; public let kind: Kind; public let layout: Layout
    public let kicker: String; public let title: String; public let sub: String?
    public let options: [OnboardingOption]
    public let requiresSex: [String]?
    public let notSure: OnboardingOption?
}

public struct Profile: Sendable, Equatable {
    public struct Watch: Sendable, Equatable { public let icon: String; public let title: String; public let sub: String }
    public let klass: String
    public let suspected: [String]
    public let watch: [Watch]
}

public enum OnboardingCatalog {
    public static let questions: [OnboardingQuestion] = [
        .init(id: "frequency", kind: .single, layout: .list, kicker: "About you", title: "How often do migraines hit?", sub: "A rough average is fine — you can refine this later.", options: [
            .init("rare", "Rarely — a few times a year"), .init("1-3mo", "1–3 days a month"), .init("weekly", "Around 1 day a week"), .init("2-3wk", "2–3 days a week"), .init("chronic", "Most days — it's constant")], requiresSex: nil, notSure: nil),
        .init(id: "duration", kind: .single, layout: .list, kicker: "About you", title: "How long have you lived with them?", sub: nil, options: [
            .init("lt1", "Less than a year"), .init("1-3", "1 to 3 years"), .init("3-10", "3 to 10 years"), .init("gt10", "Over 10 years"), .init("always", "As long as I can remember")], requiresSex: nil, notSure: nil),
        .init(id: "age", kind: .single, layout: .list, kicker: "About you", title: "Your age range", sub: "Migraine patterns shift with age, so this helps us calibrate.", options: [
            .init("u18", "Under 18"), .init("18-24", "18 – 24"), .init("25-34", "25 – 34"), .init("35-44", "35 – 44"), .init("45-54", "45 – 54"), .init("55+", "55 or older")], requiresSex: nil, notSure: nil),
        .init(id: "sex", kind: .single, layout: .list, kicker: "About you", title: "Sex assigned at birth", sub: "Hormones are one of the most common drivers, so this matters clinically.", options: [
            .init("female", "Female"), .init("male", "Male"), .init("intersex", "Intersex"), .init("na", "Prefer not to say")], requiresSex: nil, notSure: nil),
        .init(id: "cycle", kind: .single, layout: .list, kicker: "About you", title: "Do you track a menstrual cycle?", sub: "If so, Haven can line up attacks with your cycle to surface hormonal patterns.", options: [
            .init("track", "Yes — I'd like to track it"), .init("have", "I have a cycle, but won't track it"), .init("no", "No, or not applicable")], requiresSex: ["female", "intersex"], notSure: nil),
        .init(id: "aura", kind: .single, layout: .list, kicker: "Your migraines", title: "Do you get aura?", sub: "Aura is warning signs 5–60 min before the pain.", options: [
            .init("often", "Yes, most of the time"), .init("sometimes", "Sometimes"), .init("no", "No, never"), .init("unsure", "I'm not sure")], requiresSex: nil, notSure: nil),
        .init(id: "symptoms", kind: .multi, layout: .grid, kicker: "Your migraines", title: "What comes with them?", sub: "Select everything you tend to feel during an attack.", options: [
            .init("nausea", "Nausea", icon: "cup.and.saucer"), .init("light", "Light sensitivity", icon: "sun.max"), .init("sound", "Sound sensitivity", icon: "speaker.wave.2"), .init("smell", "Smell sensitivity", icon: "wind"), .init("vision", "Vision changes", icon: "eye"), .init("neck", "Neck / shoulder pain", icon: "figure.stand"), .init("dizzy", "Dizziness", icon: "waveform.path.ecg"), .init("throb", "Throbbing pain", icon: "bolt")], requiresSex: nil, notSure: nil),
        .init(id: "severity", kind: .single, layout: .list, kicker: "Your migraines", title: "At their worst, how bad do they get?", sub: "Think about how much they stop your day.", options: [
            .init("push", "I can push through it"), .init("slow", "I have to slow right down"), .init("liedown", "I need to lie down in the dark"), .init("nofunction", "I can't function at all")], requiresSex: nil, notSure: nil),
        .init(id: "triggers", kind: .multi, layout: .grid, kicker: "What you suspect", title: "What do you think sets yours off?", sub: "Pick any you suspect.", options: [
            .init("food", "Certain foods", icon: "fork.knife"), .init("alcohol", "Alcohol", icon: "wineglass"), .init("caffeine", "Caffeine", icon: "cup.and.saucer"), .init("weather", "Weather changes", icon: "cloud"), .init("stress", "Stress", icon: "bolt"), .init("sleep", "Poor sleep", icon: "moon"), .init("dehydration", "Dehydration", icon: "drop"), .init("skipped", "Skipped meals", icon: "takeoutbag.and.cup.and.straw")], requiresSex: nil, notSure: .init("unsure", "I'm honestly not sure yet")),
        .init(id: "meds", kind: .single, layout: .list, kicker: "Treatment", title: "How do you treat them now?", sub: "However you manage today is fine.", options: [
            .init("preventive", "Daily preventive medication"), .init("rescue", "Rescue meds when one hits"), .init("otc", "Over-the-counter only"), .init("supplements", "Supplements or natural remedies"), .init("nothing", "Nothing yet")], requiresSex: nil, notSure: nil),
        .init(id: "goal", kind: .multi, layout: .list, kicker: "Your goal", title: "What would make Haven worth it?", sub: "Pick all that fit.", options: [
            .init("triggers", "Pinpoint my triggers"), .init("fewer", "Have fewer attacks"), .init("doctor", "Prepare for a doctor's visit"), .init("patterns", "Understand my patterns"), .init("record", "Just keep a clear record")], requiresSex: nil, notSure: nil),
    ]
}

public func buildProfile(_ answers: [String: [String]]) -> Profile {
    let freq = answers["frequency"]?.first
    let aura = answers["aura"]?.first
    let auraYes = aura == "often" || aura == "sometimes"
    let chronic = freq == "chronic" || freq == "2-3wk"
    let klass = "\(chronic ? "Chronic" : "Episodic") migraine\(auraYes ? " with aura" : "")"

    let TRIG = ["food": "Food", "alcohol": "Alcohol", "caffeine": "Caffeine", "weather": "Weather",
                "stress": "Stress", "sleep": "Sleep", "dehydration": "Hydration", "skipped": "Meal timing"]
    let picked = (answers["triggers"] ?? []).filter { $0 != "unsure" }.compactMap { TRIG[$0] }
    let suspected = picked.isEmpty ? ["To be discovered"] : picked

    var watch: [Profile.Watch] = [
        .init(icon: "cloud", title: "Barometric weather risk", sub: "flagged before pressure swings"),
        .init(icon: "fork.knife", title: "Meals & drinks", sub: "scanned for common dietary triggers"),
        .init(icon: "moon", title: "Sleep & stress", sub: "tracked as the factors that stack up"),
    ]
    if answers["cycle"]?.first == "track" {
        watch.append(.init(icon: "waveform.path.ecg", title: "Hormonal cycle", sub: "aligned with your attacks"))
    }
    return Profile(klass: klass, suspected: suspected, watch: watch)
}
```

- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `git add HavenCore/Sources/HavenCore/Onboarding.swift HavenCore/Tests/HavenCoreTests/OnboardingTests.swift && git commit -m "feat: add onboarding question catalog and buildProfile"`

---

## Task 3: `DayDataSource.completeOnboarding` + getSettings extension + ConvexService

**Files:** Modify `HavenCore/.../{DayDataSource,Models}.swift`, `Haven/Sources/Services/ConvexService.swift`. (Build-restoration: implement ConvexService in the same task.)

- [ ] **Step 1: Extend `Settings` model** in `Models.swift`:
```swift
public struct Settings: Codable, Sendable, Equatable {
    public let theme: String
    public let onboarded: Bool
    public let subscribed: Bool
    public init(theme: String, onboarded: Bool = false, subscribed: Bool = false) {
        self.theme = theme; self.onboarded = onboarded; self.subscribed = subscribed
    }
}
```
> Optional decoding: Convex `getSettings` returns onboarded/subscribed always (defaults). If decoding older shapes, the explicit init defaults cover it; but since they're non-optional here, the query MUST return them (it does, Task 1).

- [ ] **Step 2: Extend `DayDataSource.swift`** — add:
```swift
    func completeOnboarding(answersJSON: String, reminderTime: String?, lat: Double?, lon: Double?) async throws
    func getSettings() async throws -> Settings
    func setSubscribed(_ subscribed: Bool) async throws
```

- [ ] **Step 3: Implement in `ConvexService.swift`**:
```swift
    func completeOnboarding(answersJSON: String, reminderTime: String?, lat: Double?, lon: Double?) async throws {
        var args: [String: ConvexEncodable?] = ["userId": userId, "answers": answersJSON]
        if let reminderTime { args["reminderTime"] = reminderTime }
        if let lat { args["lat"] = lat }
        if let lon { args["lon"] = lon }
        try await client.mutation("settings:completeOnboarding", with: args)
    }
    func getSettings() async throws -> Settings {
        // convex-swift 0.8.1 has NO one-shot query — take the first value off a subscription.
        let publisher: AnyPublisher<Settings, ClientError> =
            client.subscribe(to: "settings:getSettings", with: ["userId": userId], yielding: Settings.self)
        for try await value in publisher.values { return value }
        throw ClientError.InternalError  // unreachable; subscription always emits the query result
    }
    func setSubscribed(_ subscribed: Bool) async throws {
        try await client.mutation("settings:setSubscribed", with: ["userId": userId, "subscribed": subscribed])
    }
```
> VERIFIED: convex-swift 0.8.1 exposes only `subscribe`/`mutation`/`action` (no `query`). `getSettings` therefore awaits the first emission of a `getSettings` subscription via `.values` (the async sequence cancels when the loop returns). If `ClientError.InternalError` isn't a real case, use any thrown error — the line is unreachable because the reactive query emits immediately.

- [ ] **Step 4: Add the methods to `FakeSource`** in `TodayStoreTests.swift` (so it still conforms) — minimal stubs:
```swift
    var settings = Settings(theme: "dark", onboarded: false, subscribed: false)
    func completeOnboarding(answersJSON: String, reminderTime: String?, lat: Double?, lon: Double?) async throws { settings = Settings(theme: settings.theme, onboarded: true, subscribed: settings.subscribed) }
    func getSettings() async throws -> Settings { settings }
    func setSubscribed(_ subscribed: Bool) async throws { settings = Settings(theme: settings.theme, onboarded: settings.onboarded, subscribed: subscribed) }
```

- [ ] **Step 5:** `swift test --package-path HavenCore` → PASS; build the app → SUCCEEDED (conformance restored); guard pass.
- [ ] **Step 6: Commit** — `git add HavenCore/Sources/HavenCore/DayDataSource.swift HavenCore/Sources/HavenCore/Models.swift HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift Haven/Sources/Services/ConvexService.swift && git commit -m "feat: settings/onboarding methods on DayDataSource + ConvexService"`

---

## Task 4: Permission wrappers

**Files:** Create `Haven/Sources/Onboarding/Permissions.swift`.

- [ ] **Step 1: Write it** (thin async wrappers; no UI)
```swift
import Foundation
import CoreLocation
import UserNotifications

@MainActor
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    private var cont: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    func request() async -> CLLocationCoordinate2D? {
        mgr.delegate = self
        mgr.requestWhenInUseAuthorization()
        return await withCheckedContinuation { c in
            cont = c
            mgr.requestLocation()
        }
    }
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        cont?.resume(returning: locs.first?.coordinate); cont = nil
    }
    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        cont?.resume(returning: nil); cont = nil
    }
}

enum Reminders {
    static func enable() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
    static func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Haven"; content.body = "A quiet moment to log today."
        var dc = DateComponents(); dc.hour = hour; dc.minute = minute
        let req = UNNotificationRequest(identifier: "haven.daily", content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
        UNUserNotificationCenter.current().add(req)
    }
}
```

- [ ] **Step 2:** Add the Info.plist usage strings to `Haven/project.yml` settings.base:
```yaml
        INFOPLIST_KEY_NSLocationWhenInUseUsageDescription: "Haven warns you on high-risk weather days before a migraine."
```
(Notifications need no Info.plist key.)

- [ ] **Step 3: Build → SUCCEEDED, guard → pass. Commit** — `git add Haven/Sources/Onboarding/Permissions.swift Haven/project.yml && git commit -m "feat: add location + reminder permission wrappers"`

---

## Task 5: Onboarding screens

**Files:** Create `Haven/Sources/Onboarding/OnboardingFlow.swift`, `WelcomeScreen.swift`, `QuestionScreen.swift`, `SynthesisScreen.swift`, `PermScreens.swift`, `DoneScreen.swift`.

Each is tokenized SwiftUI per the prototype. Implement them with the structure below (full code).

- [ ] **Step 1: `WelcomeScreen.swift`**
```swift
import SwiftUI
import HavenDesignSystem

struct WelcomeScreen: View {
    @Environment(\.theme) private var theme
    let onStart: () -> Void
    let onSignIn: () -> Void
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Spacer()
                Image(systemName: "flame.fill").imageScale(.large).foregroundStyle(theme.accent)
                Text("Find what's been triggering your migraines.").havenText(.screenTitle, color: theme.ink)
                Text("Haven turns your daily logs — meals, weather, sleep — into a clear, personal picture of what sets your attacks off.").havenText(.body, color: theme.inkSoft)
                Spacer()
                Button(action: onStart) {
                    Text("Get started").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }.accessibilityIdentifier("ob-start")
                Button(action: onSignIn) { Text("I already have an account").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity) }
            }.padding(Spacing.s7)
        }
    }
}
```

- [ ] **Step 2: `QuestionScreen.swift`** (single/multi, list/grid)
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct QuestionScreen: View {
    @Environment(\.theme) private var theme
    let q: OnboardingQuestion
    let index: Int; let total: Int
    @Binding var selected: [String]
    let onBack: () -> Void
    let onNext: () -> Void

    private var canNext: Bool { !selected.isEmpty }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                HStack(spacing: Spacing.s3) {
                    Button(action: onBack) { Image(systemName: "chevron.left").foregroundStyle(theme.inkSoft) }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.track)
                            Capsule().fill(theme.accent).frame(width: geo.size.width * CGFloat(index + 1) / CGFloat(total))
                        }
                    }.frame(height: Spacing.s1)
                }
                Text(q.kicker.uppercased()).havenText(.eyebrow, color: theme.accent)
                Text(q.title).havenText(.screenTitle, color: theme.ink)
                if let sub = q.sub { Text(sub).havenText(.body, color: theme.inkSoft) }
                ScrollView {
                    if q.layout == .grid { grid } else { list }
                }
                Button(action: onNext) {
                    Text("Next").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(canNext ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
                }.disabled(!canNext).accessibilityIdentifier("ob-next")
            }.padding(Spacing.s7)
        }
    }

    private func toggle(_ v: String) {
        if q.kind == .single { selected = [v] }
        else if selected.contains(v) { selected.removeAll { $0 == v } }
        else { selected.append(v) }
    }

    private var list: some View {
        VStack(spacing: Spacing.s3) {
            ForEach(allOptions) { opt in
                let on = selected.contains(opt.value)
                Button { toggle(opt.value) } label: {
                    HStack {
                        Text(opt.label).havenText(.body, color: on ? theme.ctaInk : theme.ink)
                        Spacer()
                        if on { Image(systemName: "checkmark").foregroundStyle(theme.ctaInk) }
                    }
                    .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
                    .background(on ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                }
            }
        }
    }
    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s3) {
            ForEach(allOptions) { opt in
                let on = selected.contains(opt.value)
                Button { toggle(opt.value) } label: {
                    VStack(spacing: Spacing.s2) {
                        if let icon = opt.icon { Image(systemName: icon) }
                        Text(opt.label).havenText(.meta, color: on ? theme.ctaInk : theme.ink).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).frame(height: 88)
                    .background(on ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    .foregroundStyle(on ? theme.ctaInk : theme.inkSoft)
                }
            }
        }
    }
    private var allOptions: [OnboardingOption] { q.notSure.map { q.options + [$0] } ?? q.options }
}
```

- [ ] **Step 3: `SynthesisScreen.swift`**
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct SynthesisScreen: View {
    @Environment(\.theme) private var theme
    let profile: Profile
    let onNext: () -> Void
    @State private var revealed = false
    @State private var line = 0
    private let lines = ["Mapping what you've told us…", "Checking your weather sensitivity…", "Lining up suspected triggers…", "Setting your tracking baseline…"]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            if revealed { reveal } else { loading }
        }
        .task {
            for i in 0..<5 { try? await Task.sleep(nanoseconds: 600_000_000); line = i % lines.count }
            revealed = true
        }
    }

    private var loading: some View {
        VStack(spacing: Spacing.s4) {
            ProgressView()
            Text("Building your profile").havenText(.sectionHead, color: theme.ink)
            Text(lines[line]).havenText(.meta, color: theme.inkSoft)
        }.padding(Spacing.s7)
    }

    private var reveal: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            Text("Your starting point".uppercased()).havenText(.eyebrow, color: theme.accent)
            Text("Here's what we'll build on.").havenText(.screenTitle, color: theme.ink)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("YOUR PROFILE").havenText(.eyebrow, color: theme.inkFaint)
                Text(profile.klass).havenText(.sectionHead, color: theme.ink)
                FlowChips(items: ["Suspected:"] + profile.suspected)
                Divider().overlay(theme.hairline)
                Text("WHAT HAVEN WILL WATCH").havenText(.eyebrow, color: theme.inkFaint)
                ForEach(profile.watch, id: \.title) { w in
                    HStack(alignment: .top, spacing: Spacing.s3) {
                        Image(systemName: "checkmark.circle").foregroundStyle(theme.accent)
                        VStack(alignment: .leading) {
                            Text(w.title).havenText(.body, color: theme.ink)
                            Text(w.sub).havenText(.meta, color: theme.inkSoft)
                        }
                    }
                }
            }
            .padding(Spacing.s5).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
            Spacer()
            Button(action: onNext) {
                Text("Looks right").havenText(.sectionHead, color: theme.ctaInk)
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                    .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            }.accessibilityIdentifier("ob-synth-next")
        }.padding(Spacing.s7)
    }
}
```
> `FlowChips` is reused from `StatusCards.swift` (M1) — it's already in the app target.

- [ ] **Step 4: `PermScreens.swift`** (weather + reminders)
```swift
import SwiftUI
import HavenDesignSystem

struct PermWeatherScreen: View {
    @Environment(\.theme) private var theme
    let onEnable: () -> Void; let onSkip: () -> Void
    var body: some View { permBody(icon: "cloud", title: "Let Haven watch the weather for you",
        body: "A fast drop in barometric pressure is one of the most common migraine triggers. With your location, Haven warns you on high-risk days — before the attack.",
        cta: "Enable location", onCta: onEnable, onSkip: onSkip, ctaId: "ob-loc-enable") }
}

struct PermRemindersScreen: View {
    @Environment(\.theme) private var theme
    @Binding var time: String
    let onEnable: () -> Void; let onSkip: () -> Void
    private let times = [("morning","Morning","8:00 AM"),("midday","Midday","12:30 PM"),("evening","Evening","6:00 PM"),("night","Before bed","9:30 PM")]
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Spacer()
                Image(systemName: "bell").imageScale(.large).foregroundStyle(theme.accent)
                Text("One gentle nudge a day").havenText(.screenTitle, color: theme.ink)
                Text("Consistent logging is what makes the patterns show up. We'll send one quiet reminder. When suits you?").havenText(.body, color: theme.inkSoft)
                ForEach(times, id: \.0) { v, label, t in
                    let on = time == v
                    Button { time = v } label: {
                        HStack { Text(label).havenText(.body, color: on ? theme.ctaInk : theme.ink); Spacer(); Text(t).havenText(.meta, color: on ? theme.ctaInk : theme.inkSoft) }
                            .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
                            .background(on ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
                Spacer()
                Button(action: onEnable) { Text("Turn on reminders").havenText(.sectionHead, color: theme.ctaInk).frame(maxWidth: .infinity).padding(.vertical, Spacing.s5).background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg)) }.accessibilityIdentifier("ob-rem-enable")
                Button(action: onSkip) { Text("Maybe later").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity) }
            }.padding(Spacing.s7)
        }
    }
}

private extension View {
    func permBody(icon: String, title: String, body: String, cta: String, onCta: @escaping () -> Void, onSkip: @escaping () -> Void, ctaId: String) -> some View {
        PermBodyView(icon: icon, title: title, body: body, cta: cta, onCta: onCta, onSkip: onSkip, ctaId: ctaId)
    }
}
private struct PermBodyView: View {
    @Environment(\.theme) private var theme
    let icon: String; let title: String; let body: String; let cta: String
    let onCta: () -> Void; let onSkip: () -> Void; let ctaId: String
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Spacer()
                Image(systemName: icon).imageScale(.large).foregroundStyle(theme.accent)
                Text(title).havenText(.screenTitle, color: theme.ink)
                Text(body).havenText(.body, color: theme.inkSoft)
                Spacer()
                Button(action: onCta) { Text(cta).havenText(.sectionHead, color: theme.ctaInk).frame(maxWidth: .infinity).padding(.vertical, Spacing.s5).background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg)) }.accessibilityIdentifier(ctaId)
                Button(action: onSkip) { Text("Not now").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity) }
            }.padding(Spacing.s7)
        }
    }
}
```

- [ ] **Step 5: `DoneScreen.swift`**
```swift
import SwiftUI
import HavenDesignSystem

struct DoneScreen: View {
    @Environment(\.theme) private var theme
    let onEnter: () -> Void
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: Spacing.s5) {
                Spacer()
                Image(systemName: "checkmark.circle.fill").imageScale(.large).foregroundStyle(theme.accent)
                Text("You're all set").havenText(.screenTitle, color: theme.ink)
                Text("Let's log your first day and start building the picture.").havenText(.body, color: theme.inkSoft).multilineTextAlignment(.center)
                Spacer()
                Button(action: onEnter) { Text("Enter Haven").havenText(.sectionHead, color: theme.ctaInk).frame(maxWidth: .infinity).padding(.vertical, Spacing.s5).background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg)) }.accessibilityIdentifier("ob-enter")
            }.padding(Spacing.s7)
        }
    }
}
```

- [ ] **Step 6: `OnboardingFlow.swift`** (the step machine; M5-P1 skips the paywall — goes Q→synth→perms→done; P2 inserts the paywall before Done)
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct OnboardingFlow: View {
    @Environment(\.theme) private var theme
    let service: ConvexService
    let onFinished: () -> Void

    enum Step: Equatable { case welcome, question(Int), synthesis, permWeather, permReminders, done }
    @State private var step: Step = .welcome
    @State private var answers: [String: [String]] = [:]
    @State private var reminderTime = "evening"
    @State private var lat: Double?; @State private var lon: Double?
    @State private var loc = LocationOnce()

    private var visibleQuestions: [OnboardingQuestion] {
        OnboardingCatalog.questions.filter { q in
            guard let req = q.requiresSex else { return true }
            return req.contains(answers["sex"]?.first ?? "")
        }
    }

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeScreen(onStart: { step = .question(0) }, onSignIn: { step = .question(0) })
            case .question(let i):
                let q = visibleQuestions[i]
                QuestionScreen(q: q, index: i, total: visibleQuestions.count,
                    selected: bindingFor(q.id),
                    onBack: { i == 0 ? (step = .welcome) : (step = .question(i - 1)) },
                    onNext: { i + 1 < visibleQuestions.count ? (step = .question(i + 1)) : (step = .synthesis) })
                .id(q.id)
            case .synthesis:
                SynthesisScreen(profile: buildProfile(answers), onNext: { step = .permWeather })
            case .permWeather:
                PermWeatherScreen(onEnable: { Task { if let c = await loc.request() { lat = c.latitude; lon = c.longitude }; step = .permReminders } },
                                  onSkip: { step = .permReminders })
            case .permReminders:
                PermRemindersScreen(time: $reminderTime,
                    onEnable: { Task { _ = await Reminders.enable(); Reminders.schedule(hour: 18, minute: 0); await finish() } },
                    onSkip: { Task { await finish() } })
            case .done:
                DoneScreen(onEnter: onFinished)
            }
        }
    }

    private func bindingFor(_ id: String) -> Binding<[String]> {
        Binding(get: { answers[id] ?? [] }, set: { answers[id] = $0 })
    }

    private func finish() async {
        let json = (try? JSONSerialization.data(withJSONObject: answers)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        try? await service.completeOnboarding(answersJSON: json, reminderTime: reminderTime, lat: lat, lon: lon)
        step = .done
    }
}
```

- [ ] **Step 7: Build → SUCCEEDED, guard → pass.** Commit — `git add Haven/Sources/Onboarding && git commit -m "feat: add onboarding screens and flow"`

---

## Task 6: Gate in `RootView`

**Files:** Modify `Haven/Sources/RootView.swift`.

- [ ] **Step 1: Edit `RootView.swift`** — gate on `getSettings.onboarded`:
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct RootView: View {
    @State private var service = ConvexService()
    @State private var store: TodayStore?
    @State private var onboarded: Bool?

    var body: some View {
        Group {
            if let onboarded {
                if onboarded, let store {
                    RootTabView(store: store)
                } else {
                    OnboardingFlow(service: service, onFinished: { onboarded = true })
                }
            } else {
                ProgressView()   // brief settings check
            }
        }
        .task {
            let s = try? await service.getSettings()
            onboarded = s?.onboarded ?? false
            store = TodayStore(source: service, today: Self.todayString())
        }
    }

    static func todayString() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
```
> `service` is created once and shared between the onboarding (writes) and the store (reads). On finish, `onboarded` flips → RootTabView. DEBUG `sim-device` may already be onboarded from a prior run — for testing, clear settings or use a fresh device id (see Task 7).

- [ ] **Step 2: Build → SUCCEEDED, guard → pass.** Commit — `git add Haven/Sources/RootView.swift && git commit -m "feat: gate app on onboarding completion"`

---

## Task 7: Maestro + fidelity

**Files:** Create `Haven/maestro/onboarding.yaml`.

- [ ] **Step 1: Reset onboarding for the test device** — clear the `sim-device` settings so onboarding shows:
`npx convex run settings:completeOnboarding` won't help; instead delete the settings row via a one-off: `npx convex run` a small reset, OR temporarily change DEBUG device id. Simplest: run `npx convex run settings:setSubscribed '{"userId":"sim-device","subscribed":false}'` is not a reset. **Use a fresh approach:** add a dev-only `resetOnboarding` mutation OR, in `DeviceIdentity`, the DEBUG id can be overridden via an env/launch arg. For the flow, the cleanest is to assert onboarding renders on a device that hasn't onboarded — set DEBUG id to `"sim-onb"` temporarily for this test, OR clear the row:
```bash
npx convex run --push - <<'EOF'  # not standard; instead add a one-off mutation in convex/dev.ts during dev
EOF
```
Practical path: temporarily build with a fresh device id (e.g. set `DeviceIdentity.current` DEBUG to `"sim-onb-\(date)"`), run onboarding, then revert. Document what you did.

- [ ] **Step 2: Write `onboarding.yaml`**
```yaml
appId: app.haven.Haven
---
- launchApp
- assertVisible: "Find what's been triggering your migraines."
- tapOn:
    id: "ob-start"
- assertVisible: "How often do migraines hit?"
- tapOn: "Around 1 day a week"
- tapOn:
    id: "ob-next"
- assertVisible: "How long have you lived with them?"
- takeScreenshot: m5-question
```
(Drive a couple of questions; the full 11 + synthesis + perms + done is long — assert the flow advances + screenshot a question + the welcome.)

- [ ] **Step 3: Run** — `maestro test Haven/maestro/onboarding.yaml` → COMPLETED. Read `m5-question.png`.
- [ ] **Step 4: Fidelity** — compare Welcome + a QuestionScreen + Synthesis to the prototype; reconcile gaps.
- [ ] **Step 5: Commit** — `git add Haven/maestro/onboarding.yaml && git commit -m "test: add M5 onboarding Maestro flow"`

---

## Definition of done (M5-P1)
1. Fresh (non-onboarded) device shows Welcome → questions → synthesis → permissions → done → enters the app; relaunch (now onboarded) goes straight to the app.
2. `buildProfile` + the 11-question catalog correct (tests).
3. Answers/reminder/location persisted to Convex settings.
4. All suites green; guard clean; app builds; Maestro green; screens match the prototype.

## Self-review notes
- **Spec coverage:** settings backend §4 (T1), buildProfile/catalog §5 (T2), DayDataSource/ConvexService §4/§5 (T3), permissions §6 (T4), screens §6 (T5), gate §8 (T6), Maestro/fidelity §8 (T7).
- **Build continuity:** T3 grows `DayDataSource` AND implements `ConvexService` + FakeSource together → build stays green.
- **Type consistency:** `Settings` model gains onboarded/subscribed (the query returns them). answers stored as JSON string. `client.query` for getSettings (verify in T3; fallback noted). The paywall step is inserted in M5-P2 between permReminders.finish and `.done`.
- **Risks:** onboarding gate testing requires a non-onboarded device id (T7); `client.query` one-shot must exist in convex-swift 0.8.1 (verify; fallback to a first-value subscription). Permission dialogs in Maestro — the flow's skip paths avoid them.
