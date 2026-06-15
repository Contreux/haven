# Haven Profile Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Today screen's top-right `person` icon a real Profile screen that surfaces and edits the data Haven already holds (migraine profile, subscription, reminders, weather location, data/privacy).

**Architecture:** Pure mapping + report logic lives in `HavenCore` (unit-tested); new writes live in `convex` (convex-test); the `DayDataSource` protocol grows and `ConvexService` + the `FakeSource` test double implement the new methods in the same task to keep every target building; the SwiftUI `ProfileScreen` + `ProfileStore` + `QuestionEditorSheet` present it, reusing the existing `QuestionScreen`, theme tokens, and `havenText` styling.

**Tech Stack:** Swift 6 / SwiftUI (iOS 17+), Swift Testing, Convex (TypeScript) + convex-test/vitest, StoreKit 2, Maestro.

**Spec:** `docs/superpowers/specs/2026-06-15-haven-profile-screen-design.md`

## File Structure

| File | Responsibility |
|------|----------------|
| `HavenCore/Sources/HavenCore/Models.swift` | Extend `Settings` to decode `answers/reminderTime/lat/lon` |
| `HavenCore/Sources/HavenCore/AnswersCoding.swift` (new) | `answersDict(from:)` / `answersJSON(from:)` JSON helpers |
| `HavenCore/Sources/HavenCore/ProfileSummary.swift` (new) | `ProfileRow` + `profileRows(answers:)` mapping |
| `HavenCore/Sources/HavenCore/DoctorReport.swift` (new) | `DoctorReport.text(days:klass:)` plain-text export |
| `HavenCore/Sources/HavenCore/DayDataSource.swift` | Add `updateAnswers` / `setReminderTime` / `deleteMyData` |
| `convex/settings.ts` | `updateAnswers`, `setReminderTime`, `deleteAccount` mutations |
| `convex/days.ts` | `deleteAll` mutation |
| `Haven/Sources/Services/ConvexService.swift` | Implement the 3 new protocol methods |
| `HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift` | Stub the 3 new methods on `FakeSource` |
| `Haven/Sources/Profile/ProfileStore.swift` (new) | `@Observable` store: load settings, save answer, reminder, delete |
| `Haven/Sources/Profile/ProfileScreen.swift` (new) | Sectioned profile UI |
| `Haven/Sources/Profile/QuestionEditorSheet.swift` (new) | Single-question editor wrapping `QuestionScreen` |
| `Haven/Sources/Today/TopBar.swift` | Add `onProfile` callback to the `person` button |
| `Haven/Sources/Today/TodayScreen.swift` | Thread `onProfile` up |
| `Haven/Sources/App/RootTabView.swift` | Present `ProfileScreen` sheet; pass delete routing |
| `Haven/Sources/RootView.swift` | On data delete, set `onboarded = false` |
| `Haven/Sources/Onboarding/OnboardingFlow.swift` | Use `answersJSON(from:)` instead of inline `JSONSerialization` |
| `Haven/maestro/profile.yaml` (new) | UI flow: open profile, edit a question, cancel delete |

---

### Task 1: Settings decodes all backend fields + answers JSON helpers

**Files:**
- Modify: `HavenCore/Sources/HavenCore/Models.swift:64-71`
- Create: `HavenCore/Sources/HavenCore/AnswersCoding.swift`
- Test: `HavenCore/Tests/HavenCoreTests/AnswersCodingTests.swift`

- [ ] **Step 1: Write the failing test**

Create `HavenCore/Tests/HavenCoreTests/AnswersCodingTests.swift`:

```swift
import Testing
import Foundation
@testable import HavenCore

@Suite struct AnswersCodingTests {
    @Test func roundTripsSingleAndMulti() {
        let dict = ["frequency": ["weekly"], "triggers": ["food", "alcohol"]]
        let json = answersJSON(from: dict)
        #expect(answersDict(from: json) == dict)
    }
    @Test func emptyJSONDecodesToEmpty() {
        #expect(answersDict(from: "") == [:])
        #expect(answersDict(from: "{}") == [:])
    }
    @Test func settingsDecodesAnswersAndReminderAndCoords() throws {
        let json = """
        {"theme":"dark","onboarded":true,"subscribed":false,
         "answers":"{\\"frequency\\":[\\"weekly\\"]}","reminderTime":"evening","lat":51.5,"lon":-0.1}
        """.data(using: .utf8)!
        let s = try JSONDecoder().decode(Settings.self, from: json)
        #expect(s.reminderTime == "evening")
        #expect(s.lat == 51.5)
        #expect(answersDict(from: s.answers) == ["frequency": ["weekly"]])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd HavenCore && swift test --filter AnswersCodingTests 2>&1 | grep -v clocale`
Expected: FAIL — `answersJSON`/`answersDict` undefined and `Settings` has no `answers`/`reminderTime`/`lat`/`lon`.

- [ ] **Step 3: Extend `Settings`**

Replace `HavenCore/Sources/HavenCore/Models.swift:64-71` with:

```swift
public struct Settings: Codable, Sendable, Equatable {
    public let theme: String
    public let onboarded: Bool
    public let subscribed: Bool
    public let answers: String
    public let reminderTime: String
    public let lat: Double?
    public let lon: Double?
    public init(theme: String, onboarded: Bool = false, subscribed: Bool = false,
                answers: String = "", reminderTime: String = "", lat: Double? = nil, lon: Double? = nil) {
        self.theme = theme; self.onboarded = onboarded; self.subscribed = subscribed
        self.answers = answers; self.reminderTime = reminderTime; self.lat = lat; self.lon = lon
    }
}
```

- [ ] **Step 4: Create the JSON helpers**

Create `HavenCore/Sources/HavenCore/AnswersCoding.swift`:

```swift
import Foundation

/// Onboarding answers are stored as a JSON string of `{questionId: [optionValue]}`.
/// These are the single decode/encode path shared by onboarding and the profile editor.
public func answersDict(from json: String) -> [String: [String]] {
    guard let data = json.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
    else { return [:] }
    return obj
}

public func answersJSON(from dict: [String: [String]]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
          let s = String(data: data, encoding: .utf8) else { return "{}" }
    return s
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd HavenCore && swift test --filter AnswersCodingTests 2>&1 | grep -v clocale`
Expected: PASS (3 tests).

- [ ] **Step 6: Run the full HavenCore suite (Settings init change is source-compatible via defaults)**

Run: `cd HavenCore && swift test 2>&1 | grep -vE "clocale|pristine" | tail -3`
Expected: all suites pass.

- [ ] **Step 7: Commit**

```bash
git add HavenCore/Sources/HavenCore/Models.swift HavenCore/Sources/HavenCore/AnswersCoding.swift HavenCore/Tests/HavenCoreTests/AnswersCodingTests.swift
git commit -m "feat(core): Settings decodes answers/reminder/coords + answers JSON helpers"
```

---

### Task 2: ProfileSummary — answers → editable rows

**Files:**
- Create: `HavenCore/Sources/HavenCore/ProfileSummary.swift`
- Test: `HavenCore/Tests/HavenCoreTests/ProfileSummaryTests.swift`

- [ ] **Step 1: Write the failing test**

Create `HavenCore/Tests/HavenCoreTests/ProfileSummaryTests.swift`:

```swift
import Testing
@testable import HavenCore

@Suite struct ProfileSummaryTests {
    @Test func mapsSingleSelectToOptionLabel() {
        let rows = profileRows(answers: ["frequency": ["weekly"]])
        let freq = rows.first { $0.questionId == "frequency" }
        #expect(freq?.value == "Around 1 day a week")
        #expect(freq?.title == "Frequency")
    }
    @Test func joinsMultiSelectLabels() {
        let rows = profileRows(answers: ["triggers": ["food", "alcohol"]])
        let trig = rows.first { $0.questionId == "triggers" }
        #expect(trig?.value == "Certain foods, Alcohol")
    }
    @Test func omitsUnansweredQuestions() {
        let rows = profileRows(answers: ["frequency": ["weekly"]])
        #expect(rows.allSatisfy { $0.questionId != "aura" })
    }
    @Test func hidesCycleWhenSexNotApplicable() {
        let rows = profileRows(answers: ["sex": ["male"], "cycle": ["track"]])
        #expect(rows.allSatisfy { $0.questionId != "cycle" })
    }
    @Test func showsCycleWhenFemale() {
        let rows = profileRows(answers: ["sex": ["female"], "cycle": ["track"]])
        #expect(rows.contains { $0.questionId == "cycle" })
    }
    @Test func rowsFollowCatalogOrder() {
        let rows = profileRows(answers: ["aura": ["no"], "frequency": ["weekly"]])
        #expect(rows.map(\.questionId) == ["frequency", "aura"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd HavenCore && swift test --filter ProfileSummaryTests 2>&1 | grep -v clocale`
Expected: FAIL — `profileRows` / `ProfileRow` undefined.

- [ ] **Step 3: Implement `ProfileSummary.swift`**

Create `HavenCore/Sources/HavenCore/ProfileSummary.swift`:

```swift
import Foundation

public struct ProfileRow: Sendable, Equatable, Identifiable {
    public let questionId: String
    public let title: String   // short label for the row
    public let value: String   // joined selected option label(s)
    public var id: String { questionId }
}

/// Short row titles (the onboarding `title` is a full sentence; rows need a label).
private let shortTitles: [String: String] = [
    "frequency": "Frequency", "duration": "Living with them", "age": "Age",
    "sex": "Sex at birth", "cycle": "Cycle", "aura": "Aura",
    "symptoms": "Symptoms", "severity": "Severity", "triggers": "Suspected triggers",
    "meds": "Treatment", "goal": "Goals",
]

/// Builds the editable summary rows from stored answers, in catalog order.
/// Skips unanswered questions and the sex-gated `cycle` row when `sex` isn't female/intersex.
public func profileRows(answers: [String: [String]]) -> [ProfileRow] {
    let sex = answers["sex"]?.first ?? ""
    return OnboardingCatalog.questions.compactMap { q -> ProfileRow? in
        if let req = q.requiresSex, !req.contains(sex) { return nil }
        guard let picked = answers[q.id], !picked.isEmpty else { return nil }
        let allOptions = q.options + (q.notSure.map { [$0] } ?? [])
        let labels = picked.compactMap { v in allOptions.first { $0.value == v }?.label }
        guard !labels.isEmpty else { return nil }
        return ProfileRow(questionId: q.id, title: shortTitles[q.id] ?? q.title, value: labels.joined(separator: ", "))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd HavenCore && swift test --filter ProfileSummaryTests 2>&1 | grep -v clocale`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/ProfileSummary.swift HavenCore/Tests/HavenCoreTests/ProfileSummaryTests.swift
git commit -m "feat(core): profileRows maps answers to editable summary rows"
```

---

### Task 3: DoctorReport — plain-text export

**Files:**
- Create: `HavenCore/Sources/HavenCore/DoctorReport.swift`
- Test: `HavenCore/Tests/HavenCoreTests/DoctorReportTests.swift`

- [ ] **Step 1: Write the failing test**

Create `HavenCore/Tests/HavenCoreTests/DoctorReportTests.swift`:

```swift
import Testing
@testable import HavenCore

@Suite struct DoctorReportTests {
    private func day(_ date: String, migraine: Bool) -> DayLog {
        DayLog(userId: "u", date: date,
               factors: Factors(sleepHours: 7, stress: .mid, hydration: .mid, weatherSensitive: false),
               factorsLoggedAt: "09:00",
               migraine: migraine ? Migraine(had: true, severity: "moderate", time: "15:00", notes: "x") : nil,
               symptoms: migraine ? ["nausea"] : [], symptomsLoggedAt: migraine ? "15:00" : nil,
               foods: [FoodEntry(name: "Coffee", time: "08:00", triggers: [])])
    }
    @Test func headerHasClassRangeAndCount() {
        let text = DoctorReport.text(days: [day("2026-06-01", migraine: true), day("2026-06-03", migraine: false)],
                                     klass: "Episodic migraine with aura")
        #expect(text.contains("Episodic migraine with aura"))
        #expect(text.contains("2026-06-01"))
        #expect(text.contains("2026-06-03"))
        #expect(text.contains("1 migraine"))   // one attack in range
    }
    @Test func emptyDaysStillProducesHeader() {
        let text = DoctorReport.text(days: [], klass: "Episodic migraine")
        #expect(text.contains("Episodic migraine"))
        #expect(text.contains("0 migraine"))
    }
    @Test func listsAttackDaysWithSeverity() {
        let text = DoctorReport.text(days: [day("2026-06-01", migraine: true)], klass: "k")
        #expect(text.contains("2026-06-01") && text.contains("moderate"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd HavenCore && swift test --filter DoctorReportTests 2>&1 | grep -v clocale`
Expected: FAIL — `DoctorReport` undefined.

- [ ] **Step 3: Implement `DoctorReport.swift`**

Create `HavenCore/Sources/HavenCore/DoctorReport.swift`:

```swift
import Foundation

/// Plain-text migraine summary for the share-sheet export stub.
public enum DoctorReport {
    public static func text(days: [DayLog], klass: String) -> String {
        let sorted = days.sorted { $0.date < $1.date }
        let attacks = sorted.filter { $0.migraine?.had == true }
        let range = sorted.isEmpty ? "no logged days"
            : "\(sorted.first!.date) to \(sorted.last!.date)"
        var lines = [
            "Haven migraine summary",
            klass,
            "Range: \(range)",
            "\(attacks.count) migraine day(s) recorded",
            "",
        ]
        for d in attacks {
            let sev = d.migraine?.severity ?? "unknown"
            let sym = d.symptoms.isEmpty ? "" : " — \(d.symptoms.joined(separator: ", "))"
            lines.append("\(d.date): \(sev)\(sym)")
        }
        return lines.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd HavenCore && swift test --filter DoctorReportTests 2>&1 | grep -v clocale`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/DoctorReport.swift HavenCore/Tests/HavenCoreTests/DoctorReportTests.swift
git commit -m "feat(core): DoctorReport.text plain-text export"
```

---

### Task 4: Convex mutations — updateAnswers / setReminderTime / deleteAccount / days.deleteAll

**Files:**
- Modify: `convex/settings.ts`
- Modify: `convex/days.ts`
- Test: `convex/settings.test.ts`, `convex/days.test.ts`

- [ ] **Step 1: Write the failing tests**

Append to `convex/settings.test.ts`:

```typescript
test("updateAnswers patches answers, keeps onboarded", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.completeOnboarding, { userId: "dev-1", answers: '{"frequency":["weekly"]}', reminderTime: "evening" });
  await t.mutation(api.settings.updateAnswers, { userId: "dev-1", answers: '{"frequency":["chronic"]}' });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.answers).toBe('{"frequency":["chronic"]}');
  expect(s.onboarded).toBe(true);
});

test("setReminderTime patches reminder", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.setReminderTime, { userId: "dev-1", reminderTime: "morning" });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.reminderTime).toBe("morning");
});

test("deleteAccount removes the settings row (re-gates to onboarding)", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.setSubscribed, { userId: "dev-1", subscribed: true });
  await t.mutation(api.settings.deleteAccount, { userId: "dev-1" });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.onboarded).toBe(false);
});
```

Append to `convex/days.test.ts`:

```typescript
test("deleteAll removes every day doc for the user", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.seed.seed, { userId: "dev-1", today: "2026-06-15" });
  await t.mutation(api.days.deleteAll, { userId: "dev-1" });
  const rows = await t.run(async (ctx) =>
    ctx.db.query("days").withIndex("by_user_date", (q) => q.eq("userId", "dev-1")).collect());
  expect(rows.length).toBe(0);
});
```

(If `convex/days.test.ts` lacks the standard imports, mirror the header of `convex/settings.test.ts`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run convex/settings.test.ts convex/days.test.ts 2>&1 | tail -20`
Expected: FAIL — `api.settings.updateAnswers` / `setReminderTime` / `deleteAccount` / `api.days.deleteAll` undefined.

- [ ] **Step 3: Add the settings mutations**

Append to `convex/settings.ts` (reuse the existing `upsertSettings` helper):

```typescript
export const updateAnswers = mutation({
  args: { userId: v.string(), answers: v.string() },
  handler: async (ctx, { userId, answers }) => await upsertSettings(ctx, userId, { answers }),
});

export const setReminderTime = mutation({
  args: { userId: v.string(), reminderTime: v.string() },
  handler: async (ctx, { userId, reminderTime }) => await upsertSettings(ctx, userId, { reminderTime }),
});

export const deleteAccount = mutation({
  args: { userId: v.string() },
  handler: async (ctx, { userId }) => {
    const row = await ctx.db.query("settings").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    if (row) await ctx.db.delete(row._id);
  },
});
```

- [ ] **Step 4: Add the days mutation**

Append to `convex/days.ts`:

```typescript
export const deleteAll = mutation({
  args: { userId: v.string() },
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("days")
      .withIndex("by_user_date", (q) => q.eq("userId", userId))
      .collect();
    for (const row of rows) await ctx.db.delete(row._id);
    return rows.length;
  },
});
```

(Confirm `mutation` and `v` are already imported at the top of `convex/days.ts`; they are used by existing mutations there.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `npx vitest run convex/settings.test.ts convex/days.test.ts 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 6: Typecheck + deploy**

Run: `npx convex deploy 2>&1 | tail -5`
Expected: deploy succeeds (functions ready).

- [ ] **Step 7: Commit**

```bash
git add convex/settings.ts convex/days.ts convex/settings.test.ts convex/days.test.ts
git commit -m "feat(convex): updateAnswers, setReminderTime, deleteAccount, days.deleteAll"
```

---

### Task 5: Grow DayDataSource + implement in ConvexService and FakeSource

This task grows the protocol and implements it everywhere in one shot so all targets keep building (the established "protocol grows → build breaks" guard for this repo).

**Files:**
- Modify: `HavenCore/Sources/HavenCore/DayDataSource.swift:22`
- Modify: `Haven/Sources/Services/ConvexService.swift` (after line 124)
- Modify: `HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift:91`

- [ ] **Step 1: Add the protocol methods**

In `HavenCore/Sources/HavenCore/DayDataSource.swift`, after the `validateSubscription` line (currently line 22), add:

```swift
    func updateAnswers(_ json: String) async throws
    func setReminderTime(_ time: String) async throws
    func deleteMyData() async throws
```

- [ ] **Step 2: Run HavenCore tests to verify the build breaks**

Run: `cd HavenCore && swift test 2>&1 | grep -vE "clocale|pristine" | grep -iE "error|does not conform" | head`
Expected: FAIL — `FakeSource` does not conform (missing 3 methods).

- [ ] **Step 3: Stub the methods on `FakeSource`**

In `HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift`, after the `validateSubscription` stub (currently line 91), add:

```swift
    private(set) var updatedAnswers: String?
    func updateAnswers(_ json: String) async throws { updatedAnswers = json }
    func setReminderTime(_ time: String) async throws { settings = Settings(theme: settings.theme, onboarded: settings.onboarded, subscribed: settings.subscribed, answers: settings.answers, reminderTime: time) }
    func deleteMyData() async throws { settings = Settings(theme: settings.theme) }
```

- [ ] **Step 4: Run HavenCore tests to verify they pass**

Run: `cd HavenCore && swift test 2>&1 | grep -vE "clocale|pristine" | tail -3`
Expected: all pass.

- [ ] **Step 5: Implement the methods on `ConvexService`**

In `Haven/Sources/Services/ConvexService.swift`, after `setSubscribed` (line ~124), add:

```swift
    func updateAnswers(_ json: String) async throws {
        try await client.mutation("settings:updateAnswers", with: ["userId": userId, "answers": json])
    }
    func setReminderTime(_ time: String) async throws {
        try await client.mutation("settings:setReminderTime", with: ["userId": userId, "reminderTime": time])
    }
    func deleteMyData() async throws {
        try await client.mutation("days:deleteAll", with: ["userId": userId])
        try await client.mutation("settings:deleteAccount", with: ["userId": userId])
    }
```

- [ ] **Step 6: Build the app to verify ConvexService conforms**

Run: `cd Haven && xcodebuild -project Haven.xcodeproj -scheme Haven -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/haven-dd build 2>&1 | grep -iE "BUILD SUCCEEDED|BUILD FAILED|error:" | head`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add HavenCore/Sources/HavenCore/DayDataSource.swift Haven/Sources/Services/ConvexService.swift HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift
git commit -m "feat: DayDataSource gains updateAnswers/setReminderTime/deleteMyData"
```

---

### Task 6: ProfileStore + TopBar wiring + ProfileScreen scaffold

Build a minimal but presentable Profile screen wired to the icon, with header + a placeholder body. Sections are filled in Tasks 7–9. Verified by build + screenshot (UI tasks aren't unit-tested here).

**Files:**
- Create: `Haven/Sources/Profile/ProfileStore.swift`
- Create: `Haven/Sources/Profile/ProfileScreen.swift`
- Modify: `Haven/Sources/Today/TopBar.swift`
- Modify: `Haven/Sources/Today/TodayScreen.swift`
- Modify: `Haven/Sources/App/RootTabView.swift`

- [ ] **Step 1: Create `ProfileStore`**

Create `Haven/Sources/Profile/ProfileStore.swift`:

```swift
import SwiftUI
import HavenCore

@MainActor @Observable
final class ProfileStore {
    private let source: DayDataSource
    private(set) var answers: [String: [String]] = [:]
    private(set) var settings: Settings = Settings(theme: "dark")
    var days: [DayLog] = []

    init(source: DayDataSource) { self.source = source }

    var profile: Profile { buildProfile(answers) }
    var rows: [ProfileRow] { profileRows(answers: answers) }

    func load() async {
        if let s = try? await source.getSettings() {
            settings = s
            answers = answersDict(from: s.answers)
        }
        source.observeDays { [weak self] in self?.days = $0 }
    }

    func saveAnswer(questionId: String, values: [String]) async {
        answers[questionId] = values
        try? await source.updateAnswers(answersJSON(from: answers))
    }

    func setReminderTime(_ time: String) async {
        settings = Settings(theme: settings.theme, onboarded: settings.onboarded, subscribed: settings.subscribed,
                            answers: settings.answers, reminderTime: time, lat: settings.lat, lon: settings.lon)
        try? await source.setReminderTime(time)
    }

    func deleteData() async { try? await source.deleteMyData() }
}
```

- [ ] **Step 2: Create the `ProfileScreen` scaffold**

Create `Haven/Sources/Profile/ProfileScreen.swift`:

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct ProfileScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store: ProfileStore
    let onDataDeleted: () -> Void

    init(source: DayDataSource, onDataDeleted: @escaping () -> Void) {
        _store = State(initialValue: ProfileStore(source: source))
        self.onDataDeleted = onDataDeleted
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    header
                    // Sections added in Tasks 7–9.
                }
                .padding(Spacing.s7)
            }
        }
        .task { await store.load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Your profile").havenText(.screenTitle, color: theme.ink)
                Text(store.profile.klass).havenText(.body, color: theme.inkSoft)
                Text("Sign in to sync (coming soon)").havenText(.meta, color: theme.inkFaint)
            }
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(theme.inkSoft) }
                .accessibilityIdentifier("profile-close")
        }
    }
}
```

- [ ] **Step 3: Add `onProfile` to `TopBar`**

In `Haven/Sources/Today/TopBar.swift`, add a stored callback and trigger it from the `person` button. Replace the struct's stored properties and the `iconButton` usage:

Add after `let streak: Int` (line 7):
```swift
    var onProfile: () -> Void = {}
```
Replace `iconButton("person")` (line 27) with:
```swift
                iconButton("person", action: onProfile, id: "open-profile")
```
Replace the `iconButton` helper (lines 33-40) with:
```swift
    private func iconButton(_ name: String, action: @escaping () -> Void = {}, id: String? = nil) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .foregroundStyle(theme.inkSoft)
                .frame(width: 38, height: 38)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        }
        .accessibilityIdentifier(id ?? name)
    }
```

- [ ] **Step 4: Thread `onProfile` through `TodayScreen`**

In `Haven/Sources/Today/TodayScreen.swift`: add a stored `onProfile` and pass it to `TopBar`.

Add alongside `onLogger` (near line 8):
```swift
    private let onProfile: () -> Void
```
Update the `init` (line 10-13) to accept and store it:
```swift
    init(store: TodayStore, onLogger: @escaping (LoggerKind) -> Void, onProfile: @escaping () -> Void = {}) {
        self.store = store
        self.onLogger = onLogger
        self.onProfile = onProfile
    }
```
Update the `TopBar(...)` call (line 20):
```swift
                    TopBar(dateText: prettyDate(store.today), streak: store.streak, onProfile: onProfile)
```
(If `store` is assigned via `_store = State(...)` rather than `self.store =`, match the existing assignment style in that init.)

- [ ] **Step 5: Present `ProfileScreen` from `RootTabView`**

In `Haven/Sources/App/RootTabView.swift`:

Add state near the other `@State` (after line 10):
```swift
    @State private var showProfile = false
    var onDataDeleted: () -> Void = {}
```
Update the Today case (line 19):
```swift
            case .today: TodayScreen(store: store, onLogger: { activeSheet = $0 }, onProfile: { showProfile = true })
```
Add a sheet modifier after the existing `.sheet(item:)` (line 27):
```swift
        .sheet(isPresented: $showProfile) {
            if let service = store.source as? ConvexService {
                ProfileScreen(source: service, onDataDeleted: { showProfile = false; onDataDeleted() })
                    .environment(\.theme, theme)
            }
        }
```

- [ ] **Step 6: Pass delete routing from `RootView`**

In `Haven/Sources/RootView.swift`, update the `RootTabView(store:)` call (line 14):
```swift
                    RootTabView(store: store, onDataDeleted: { onboarded = false })
```

- [ ] **Step 7: Build + screenshot**

Run:
```bash
cd Haven && xcodebuild -project Haven.xcodeproj -scheme Haven -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/haven-dd build 2>&1 | grep -iE "BUILD SUCCEEDED|BUILD FAILED|error:" | head
APP=$(find /tmp/haven-dd -name Haven.app -type d | head -1)
xcrun simctl install booted "$APP"; xcrun simctl launch booted app.haven.Haven; sleep 3
xcrun simctl io booted screenshot /tmp/profile-scaffold.png
```
Expected: BUILD SUCCEEDED; tapping the top-right person icon opens a sheet showing "Your profile" + the migraine class. (Read `/tmp/profile-scaffold.png` to confirm.)

- [ ] **Step 8: Commit**

```bash
git add Haven/Sources/Profile/ProfileStore.swift Haven/Sources/Profile/ProfileScreen.swift Haven/Sources/Today/TopBar.swift Haven/Sources/Today/TodayScreen.swift Haven/Sources/App/RootTabView.swift Haven/Sources/RootView.swift
git commit -m "feat(app): profile icon opens ProfileScreen scaffold"
```

---

### Task 7: Editable migraine-profile section + QuestionEditorSheet

**Files:**
- Create: `Haven/Sources/Profile/QuestionEditorSheet.swift`
- Modify: `Haven/Sources/Profile/ProfileScreen.swift`

- [ ] **Step 1: Create `QuestionEditorSheet`**

Create `Haven/Sources/Profile/QuestionEditorSheet.swift`. It reuses `QuestionScreen` with a local binding and saves on dismiss:

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct QuestionEditorSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let question: OnboardingQuestion
    @State var selection: [String]
    let onSave: ([String]) -> Void

    var body: some View {
        QuestionScreen(
            q: question, index: 0, total: 1,
            selected: $selection,
            onBack: { dismiss() },
            onNext: { onSave(selection); dismiss() }
        )
        .environment(\.theme, theme)
    }
}
```

- [ ] **Step 2: Add the editable section to `ProfileScreen`**

In `Haven/Sources/Profile/ProfileScreen.swift`, add editing state and the section. Add state properties after `@State private var store`:

```swift
    @State private var editing: OnboardingQuestion?
```

Add this computed section and insert `profileSection` into the `VStack` right after `header`:

```swift
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("YOUR MIGRAINE PROFILE").havenText(.eyebrow, color: theme.inkFaint)
            ForEach(store.rows) { row in
                Button { editing = OnboardingCatalog.questions.first { $0.id == row.questionId } } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text(row.title).havenText(.meta, color: theme.inkSoft)
                            Text(row.value).havenText(.body, color: theme.ink)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(theme.inkFaint)
                    }
                    .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .accessibilityIdentifier("profile-row-\(row.questionId)")
            }
        }
    }
```

Add the editor sheet modifier on the root `ZStack` (alongside `.task`):

```swift
        .sheet(item: $editing) { q in
            QuestionEditorSheet(question: q, selection: store.answers[q.id] ?? []) { values in
                Task { await store.saveAnswer(questionId: q.id, values: values) }
            }
            .environment(\.theme, theme)
        }
```

And insert `profileSection` into the VStack:
```swift
                    header
                    profileSection
```

(`OnboardingQuestion` already conforms to `Identifiable` via its `id`, so it works as `sheet(item:)`.)

- [ ] **Step 3: Build + screenshot the editing flow**

Run:
```bash
cd Haven && xcodebuild -project Haven.xcodeproj -scheme Haven -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/haven-dd build 2>&1 | grep -iE "BUILD SUCCEEDED|BUILD FAILED|error:" | head
APP=$(find /tmp/haven-dd -name Haven.app -type d | head -1)
xcrun simctl install booted "$APP"; xcrun simctl launch booted app.haven.Haven; sleep 3
xcrun simctl io booted screenshot /tmp/profile-rows.png
```
Expected: BUILD SUCCEEDED; profile shows editable rows; tapping one opens the question editor. (Read `/tmp/profile-rows.png`.)

- [ ] **Step 4: Commit**

```bash
git add Haven/Sources/Profile/QuestionEditorSheet.swift Haven/Sources/Profile/ProfileScreen.swift
git commit -m "feat(app): editable migraine-profile rows via QuestionEditorSheet"
```

---

### Task 8: Subscription, Reminders, Weather & About sections

**Files:**
- Modify: `Haven/Sources/Profile/ProfileScreen.swift`

- [ ] **Step 1: Add the sections**

In `Haven/Sources/Profile/ProfileScreen.swift`:

Add imports at top: `import StoreKit`.
Add environment for theme toggle after `@Environment(\.dismiss)`:
```swift
    @Environment(ThemeController.self) private var themeController
```
Add reminder state after `@State private var editing`:
```swift
    @State private var reminder = "evening"
```

Add these computed sections and insert them into the VStack after `profileSection`:

```swift
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(title).havenText(.eyebrow, color: theme.inkFaint)
            content()
                .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    private var subscriptionSection: some View {
        sectionCard("SUBSCRIPTION") {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text(store.settings.subscribed ? "Haven Premium — active" : "Free plan")
                    .havenText(.body, color: theme.ink)
                HStack(spacing: Spacing.s5) {
                    Button("Manage") { Task { try? await AppStore.showManageSubscriptions(in: scene) } }
                        .havenText(.meta, color: theme.accent)
                    Button("Restore") { /* entitlement check */ }
                        .havenText(.meta, color: theme.accent)
                        .accessibilityIdentifier("profile-restore")
                }
            }
        }
    }

    private var remindersSection: some View {
        sectionCard("REMINDERS") {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Daily reminder").havenText(.body, color: theme.ink)
                Picker("", selection: $reminder) {
                    Text("Morning").tag("morning"); Text("Afternoon").tag("afternoon"); Text("Evening").tag("evening")
                }
                .pickerStyle(.segmented)
                .onChange(of: reminder) { _, t in Task { await store.setReminderTime(t) } }
            }
        }
    }

    private var weatherSection: some View {
        sectionCard("WEATHER & LOCATION") {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text(store.settings.lat == nil ? "Barometric risk off" : "Barometric risk on")
                    .havenText(.body, color: theme.ink)
                if let lat = store.settings.lat, let lon = store.settings.lon {
                    Text(String(format: "%.2f, %.2f", lat, lon)).havenText(.meta, color: theme.inkSoft)
                } else {
                    Text("Location not set").havenText(.meta, color: theme.inkSoft)
                }
            }
        }
    }

    private var aboutSection: some View {
        sectionCard("ABOUT") {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HStack {
                    Text("Dark theme").havenText(.body, color: theme.ink)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { themeController.mode == .dark },
                        set: { _ in themeController.toggle() })).labelsHidden()
                }
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .havenText(.meta, color: theme.inkFaint)
            }
        }
    }

    private var scene: UIWindowScene {
        UIApplication.shared.connectedScenes.first as! UIWindowScene
    }
```

Initialise `reminder` from settings in `.task`: after `await store.load()` add:
```swift
            reminder = store.settings.reminderTime.isEmpty ? "evening" : store.settings.reminderTime
```

Insert into the VStack after `profileSection`:
```swift
                    subscriptionSection
                    remindersSection
                    weatherSection
                    aboutSection
```

- [ ] **Step 2: Build + screenshot**

Run:
```bash
cd Haven && xcodebuild -project Haven.xcodeproj -scheme Haven -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/haven-dd build 2>&1 | grep -iE "BUILD SUCCEEDED|BUILD FAILED|error:" | head
APP=$(find /tmp/haven-dd -name Haven.app -type d | head -1)
xcrun simctl install booted "$APP"; xcrun simctl launch booted app.haven.Haven; sleep 3
xcrun simctl io booted screenshot /tmp/profile-sections.png
```
Expected: BUILD SUCCEEDED; all sections render. (Read `/tmp/profile-sections.png`.)

- [ ] **Step 3: Commit**

```bash
git add Haven/Sources/Profile/ProfileScreen.swift
git commit -m "feat(app): subscription, reminders, weather, about sections"
```

---

### Task 9: Data & privacy — export share stub + delete with routing

**Files:**
- Modify: `Haven/Sources/Profile/ProfileScreen.swift`

- [ ] **Step 1: Add the data & privacy section**

In `Haven/Sources/Profile/ProfileScreen.swift`, add delete-confirm state after `@State private var reminder`:

```swift
    @State private var confirmingDelete = false
```

Add the section:

```swift
    private var dataSection: some View {
        sectionCard("DATA & PRIVACY") {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                ShareLink(item: DoctorReport.text(days: store.days, klass: store.profile.klass)) {
                    HStack { Text("Export report").havenText(.body, color: theme.ink); Spacer()
                        Image(systemName: "square.and.arrow.up").foregroundStyle(theme.inkFaint) }
                }
                .accessibilityIdentifier("profile-export")
                Button { confirmingDelete = true } label: {
                    HStack { Text("Delete my data").havenText(.body, color: theme.danger); Spacer()
                        Image(systemName: "trash").foregroundStyle(theme.danger) }
                }
                .accessibilityIdentifier("profile-delete")
            }
        }
    }
```

Add the confirmation modifier on the root `ZStack`:

```swift
        .confirmationDialog("Delete all your data?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                Task { await store.deleteData(); onDataDeleted() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your logs and profile, and returns you to setup.")
        }
```

Insert `dataSection` into the VStack after `aboutSection`.

(Confirm `theme.danger` exists in `Theme`; if the token is named differently, use the existing destructive/red token — grep `Theme.swift` for `danger`/`warn`/`alert` and use that.)

- [ ] **Step 2: Verify the danger token name**

Run: `grep -nE "danger|alert|warn|red|destructive" HavenDesignSystem/Sources/HavenDesignSystem/Theme.swift`
Expected: shows the destructive color token; adjust `theme.danger` in Step 1 to match the real name if needed.

- [ ] **Step 3: Build + screenshot**

Run:
```bash
cd Haven && xcodebuild -project Haven.xcodeproj -scheme Haven -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/haven-dd build 2>&1 | grep -iE "BUILD SUCCEEDED|BUILD FAILED|error:" | head
APP=$(find /tmp/haven-dd -name Haven.app -type d | head -1)
xcrun simctl install booted "$APP"; xcrun simctl launch booted app.haven.Haven; sleep 3
xcrun simctl io booted screenshot /tmp/profile-data.png
```
Expected: BUILD SUCCEEDED; export + delete rows render; delete shows a confirmation dialog. (Read `/tmp/profile-data.png`.)

- [ ] **Step 4: Commit**

```bash
git add Haven/Sources/Profile/ProfileScreen.swift
git commit -m "feat(app): data & privacy — export stub + delete with routing"
```

---

### Task 10: OnboardingFlow uses shared answers encoder + Maestro flow + final review

**Files:**
- Modify: `Haven/Sources/Onboarding/OnboardingFlow.swift:72-76`
- Create: `Haven/maestro/profile.yaml`

- [ ] **Step 1: DRY the onboarding encoder**

In `Haven/Sources/Onboarding/OnboardingFlow.swift`, replace the inline JSON in `finish` (lines 72-76):

```swift
    private func finish(subscribed: Bool) async {
        try? await service.completeOnboarding(answersJSON: answersJSON(from: answers), reminderTime: reminderTime, lat: lat, lon: lon)
        step = .done
    }
```

- [ ] **Step 2: Build to confirm onboarding still compiles**

Run: `cd Haven && xcodebuild -project Haven.xcodeproj -scheme Haven -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/haven-dd build 2>&1 | grep -iE "BUILD SUCCEEDED|BUILD FAILED|error:" | head`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Write the Maestro flow**

Create `Haven/maestro/profile.yaml`:

```yaml
appId: app.haven.Haven
---
- launchApp
- tapOn:
    id: "open-profile"
- assertVisible: "Your profile"
- tapOn:
    id: "profile-row-frequency"
- assertVisible: "How often do migraines hit?"
- tapOn:
    id: "ob-next"
- assertVisible: "Your profile"
- tapOn:
    id: "profile-delete"
- assertVisible: "Delete all your data?"
- tapOn: "Cancel"
- assertVisible: "Your profile"
```

- [ ] **Step 4: Run the Maestro flow**

Run:
```bash
APP=$(find /tmp/haven-dd -name Haven.app -type d | head -1)
xcrun simctl install booted "$APP"
~/.maestro/bin/maestro test Haven/maestro/profile.yaml 2>&1 | tail -20
```
Expected: flow passes (all assertions green). If an icon-only `tapOn: id` fails to resolve, fall back to a point tap as documented for this repo's nav.

- [ ] **Step 5: Full regression — all test suites**

Run:
```bash
cd HavenCore && swift test 2>&1 | grep -vE "clocale|pristine" | tail -2
cd ../HavenDesignSystem && swift test 2>&1 | grep -vE "clocale|pristine" | tail -2
cd .. && npx vitest run 2>&1 | tail -5
```
Expected: HavenCore, HavenDesignSystem, and Convex suites all pass.

- [ ] **Step 6: Commit**

```bash
git add Haven/Sources/Onboarding/OnboardingFlow.swift Haven/maestro/profile.yaml
git commit -m "feat(app): onboarding shares answers encoder + profile Maestro flow"
```

---

## Self-Review

**Spec coverage:**
- Header/class → Task 6. Editable migraine profile → Tasks 2, 7. Subscription → Task 8. Reminders → Tasks 4, 8. Weather/location → Task 8. Data & privacy (export stub + delete + routing) → Tasks 3, 9, 6. About/theme → Task 8. `Settings` field gap → Task 1. Protocol growth without breaking build → Task 5. Onboarding DRY → Task 10. Maestro + regression → Task 10. All covered.

**Type consistency:** `profileRows(answers:)`/`ProfileRow`, `answersDict(from:)`/`answersJSON(from:)`, `DoctorReport.text(days:klass:)`, `updateAnswers/setReminderTime/deleteMyData`, and the Convex names `settings:updateAnswers`/`settings:setReminderTime`/`settings:deleteAccount`/`days:deleteAll` are used identically across HavenCore, ConvexService, FakeSource, and the UI.

**Known verification points flagged inline (not placeholders):** the `theme.danger` token name (Task 9 Step 2 verifies it) and the exact `TodayScreen`/`RootTabView` init-assignment style (match existing) — both are explicit check-then-adjust steps, not deferred work.
