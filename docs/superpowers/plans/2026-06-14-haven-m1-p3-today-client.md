# Haven M1 · Plan 3 — Today Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the **Today** screen — the M1 finish line — rendering live, reactive Convex data through fully tokenized SwiftUI, with a working factor-editor write path that round-trips through the backend, and a "Logged today" **ledger** that merges every log type into one time-sorted list.

**Architecture:** Pure logic (Codable models, the ledger builder, the weather stub, the streak calc, and the `TodayStore` view-model driving off a `DayDataSource` protocol) lives in a new headless-testable Swift package **`HavenCore`** — so the whole data layer is covered by `swift test` with no simulator and no Convex dependency. The app target supplies the one concrete adapter that touches the network: `ConvexService` (wrapping `ConvexMobile`/`convex-swift`), which conforms to `DayDataSource`. Every visual value comes from P1's `HavenDesignSystem`; the token guard must stay green.

**Tech Stack:** Swift 6 / SwiftUI · Swift Testing · `convex-swift` (ConvexMobile, Combine publishers) · XcodeGen · P1's `HavenDesignSystem` · P2's Convex deployment.

**Reference docs:** spec `docs/superpowers/specs/2026-06-14-haven-m1-foundation-today-design.md` (§6 + §6.5), P2 plan (data shapes — the field names here MUST match), `HavenDesignSystem/README.md` (tokens), ConvexMobile API: https://docs.convex.dev/client/swift.

---

## Scope & dependencies

- **Depends on:** P1 (the `HavenDesignSystem` package + app shell + guard script) and P2 (the deployed Convex backend + its exact field names + the recorded deployment URL).
- **Produces:** the live Today screen wired into the app, plus a headless-tested `HavenCore` data layer.
- **Out of scope:** Calendar/Insights/Weather tabs and the bottom tab bar (M3/M4), real barometric weather (M4 — stubbed here), food capture + AI (M2 — foods are read-only from seed here), onboarding/paywall (M5), the polished daily-factors sheet (M2 — a minimal editor proves the write path).

## Data contract (must match P2 exactly)

`days` document fields consumed here: `userId`, `date`, `factors{ sleepHours, stress, hydration, weatherSensitive }`, `factorsLoggedAt`, `migraine{ had, severity, time, notes }`, `symptoms[]`, `symptomsLoggedAt`, `foods[]{ name, time, triggers[]{ label, level } }`. `level` is `"low" | "mid" | "high"`. Convex queries take `userId` (device id) + `date`. The dev device id is `"sim-device"` (seeded in P2 Task 7).

## File structure

```
HavenCore/                                   # new headless-testable Swift package
├── Package.swift
├── Sources/HavenCore/
│   ├── Models.swift                         # DayLog, Factors, Migraine, FoodEntry, TriggerChip, Settings + Level
│   ├── Weather.swift                        # Weather model + WeatherStub
│   ├── Ledger.swift                         # LedgerEntry + buildLedger(from:) pure function
│   ├── Streak.swift                         # streak(of:asOf:) pure function
│   ├── DayDataSource.swift                  # protocol the app's ConvexService conforms to
│   └── TodayStore.swift                     # @Observable view-model
└── Tests/HavenCoreTests/
    ├── ModelsTests.swift
    ├── WeatherStubTests.swift
    ├── LedgerTests.swift
    ├── StreakTests.swift
    └── TodayStoreTests.swift

Haven/Sources/                               # app target (extends P1)
├── Services/
│   ├── ConvexService.swift                  # ConvexMobile adapter → DayDataSource
│   └── DeviceIdentity.swift                 # persisted device UUID ("sim-device" in DEBUG)
├── Today/
│   ├── TodayScreen.swift                    # assembly
│   ├── TopBar.swift
│   ├── RiskHero.swift
│   ├── FactorRings.swift                    # + FactorEditor (write path)
│   ├── ActionButtons.swift
│   ├── StatusCards.swift                    # MigraineAlertCard + SummaryCard
│   └── LedgerView.swift                     # LedgerList + the per-type row views
└── RootView.swift                           # MODIFIED to host TodayScreen
Haven/project.yml                            # MODIFIED: add HavenCore + convex-swift deps
```

---

## Task 1: `HavenCore` package skeleton

**Files:**
- Create: `HavenCore/Package.swift`

- [ ] **Step 1: Write `HavenCore/Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HavenCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HavenCore", targets: ["HavenCore"]),
    ],
    targets: [
        .target(name: "HavenCore"),
        .testTarget(name: "HavenCoreTests", dependencies: ["HavenCore"]),
    ]
)
```

> No `ConvexMobile` dependency here — that lives only in the app target, keeping `swift test` headless and network-free.

- [ ] **Step 2: Create dirs + placeholder, verify it resolves**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine
mkdir -p HavenCore/Sources/HavenCore HavenCore/Tests/HavenCoreTests
printf 'import Foundation\n' > HavenCore/Sources/HavenCore/Models.swift
swift build --package-path HavenCore
```
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add HavenCore/Package.swift HavenCore/Sources HavenCore/Tests
git commit -m "chore: scaffold HavenCore Swift package"
```

---

## Task 2: Codable models

Decoded from Convex documents. Convex sends extra fields (`_id`, `_creationTime`); decoding ignores unknown keys by default, so models list only what they need.

**Files:**
- Modify: `HavenCore/Sources/HavenCore/Models.swift`
- Test: `HavenCore/Tests/HavenCoreTests/ModelsTests.swift`

- [ ] **Step 1: Write the failing test** (decodes a realistic Convex JSON day)

```swift
import Testing
import Foundation
@testable import HavenCore

@Suite struct ModelsTests {
    static let dayJSON = """
    {
      "_id": "abc", "_creationTime": 1.0,
      "userId": "sim-device", "date": "2026-06-14",
      "factors": { "sleepHours": 6.5, "stress": "high", "hydration": "low", "weatherSensitive": true },
      "factorsLoggedAt": "09:02",
      "migraine": { "had": true, "severity": "moderate", "time": "15:10", "notes": "left eye" },
      "symptoms": ["nausea", "aura"], "symptomsLoggedAt": "14:40",
      "foods": [
        { "name": "Aged cheddar", "time": "12:30", "triggers": [ { "label": "Tyramine", "level": "high" } ] }
      ]
    }
    """

    @Test func decodesFullDay() throws {
        let day = try JSONDecoder().decode(DayLog.self, from: Data(Self.dayJSON.utf8))
        #expect(day.date == "2026-06-14")
        #expect(day.factors?.sleepHours == 6.5)
        #expect(day.factors?.stress == .high)
        #expect(day.migraine?.had == true)
        #expect(day.symptoms == ["nausea", "aura"])
        #expect(day.symptomsLoggedAt == "14:40")
        #expect(day.foods.first?.triggers.first?.level == .high)
    }

    @Test func decodesSparseDay() throws {
        let json = #"{ "userId": "d", "date": "2026-06-11", "symptoms": [], "foods": [] }"#
        let day = try JSONDecoder().decode(DayLog.self, from: Data(json.utf8))
        #expect(day.factors == nil)
        #expect(day.migraine == nil)
        #expect(day.symptoms.isEmpty)
        #expect(day.foods.isEmpty)
    }

    @Test func levelDecodesFromString() throws {
        #expect(try JSONDecoder().decode(Level.self, from: Data("\"mid\"".utf8)) == .mid)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HavenCore`
Expected: FAIL — `DayLog` etc. undefined.

- [ ] **Step 3: Implement `Models.swift`**

```swift
import Foundation

public enum Level: String, Codable, Sendable, Equatable {
    case low, mid, high
}

public struct TriggerChip: Codable, Sendable, Equatable, Identifiable {
    public let label: String
    public let level: Level
    public var id: String { label }
}

public struct FoodEntry: Codable, Sendable, Equatable {
    public let name: String
    public let time: String          // "HH:mm"
    public let triggers: [TriggerChip]
}

public struct Factors: Codable, Sendable, Equatable {
    public let sleepHours: Double
    public let stress: Level
    public let hydration: Level
    public let weatherSensitive: Bool

    public init(sleepHours: Double, stress: Level, hydration: Level, weatherSensitive: Bool) {
        self.sleepHours = sleepHours; self.stress = stress
        self.hydration = hydration; self.weatherSensitive = weatherSensitive
    }
}

public struct Migraine: Codable, Sendable, Equatable {
    public let had: Bool
    public let severity: String
    public let time: String          // "HH:mm"
    public let notes: String
}

public struct DayLog: Codable, Sendable, Equatable {
    public let userId: String
    public let date: String          // "YYYY-MM-DD"
    public let factors: Factors?
    public let factorsLoggedAt: String?
    public let migraine: Migraine?
    public let symptoms: [String]
    public let symptomsLoggedAt: String?
    public let foods: [FoodEntry]
}

public struct Settings: Codable, Sendable, Equatable {
    public let theme: String
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path HavenCore`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/Models.swift HavenCore/Tests/HavenCoreTests/ModelsTests.swift
git commit -m "feat: add Codable models for the day log"
```

---

## Task 3: Weather model + deterministic stub

**Files:**
- Create: `HavenCore/Sources/HavenCore/Weather.swift`
- Test: `HavenCore/Tests/HavenCoreTests/WeatherStubTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import HavenCore

@Suite struct WeatherStubTests {
    @Test func stubIsDeterministicForADate() {
        let a = WeatherStub.weather(for: "2026-06-14")
        let b = WeatherStub.weather(for: "2026-06-14")
        #expect(a == b)
    }
    @Test func barsMatchLevel() {
        let w = WeatherStub.weather(for: "2026-06-14")
        #expect(w.bars >= 1 && w.bars <= 4)
        switch w.level {
        case .low: #expect(w.bars <= 2)
        case .mid: #expect(w.bars == 3)
        case .high: #expect(w.bars == 4)
        }
    }
    @Test func headlineNonEmpty() {
        #expect(WeatherStub.weather(for: "2026-06-14").headline.isEmpty == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HavenCore`
Expected: FAIL — `Weather` / `WeatherStub` undefined.

- [ ] **Step 3: Implement `Weather.swift`**

```swift
import Foundation

public struct Weather: Sendable, Equatable {
    public let level: Level          // reuses the factor color mapping in the UI
    public let bars: Int             // 1...4 gauge fill
    public let tempSwing: Int        // °, magnitude of change
    public let humidity: Int         // %
    public let temp: Int             // current °
    public let trend: String         // "rising" | "falling" | "steady"
    public let headline: String
    public let detail: String
}

/// Deterministic mock matching the real `fetchWeather` contract (swapped in M4).
public enum WeatherStub {
    public static func weather(for date: String) -> Weather {
        // Deterministic pseudo-random from the date string.
        let seed = date.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let levels: [Level] = [.low, .mid, .high]
        let level = levels[seed % 3]
        let bars: Int
        let headline: String
        let detail: String
        switch level {
        case .low:
            bars = 2; headline = "Calm pressure"
            detail = "Stable barometric pressure today — low trigger risk."
        case .mid:
            bars = 3; headline = "Shifting front"
            detail = "Moderate pressure swing this afternoon."
        case .high:
            bars = 4; headline = "Storm incoming"
            detail = "Sharp pressure drop expected — elevated migraine risk."
        }
        return Weather(
            level: level, bars: bars,
            tempSwing: 4 + (seed % 6), humidity: 55 + (seed % 30),
            temp: 14 + (seed % 12), trend: seed % 2 == 0 ? "falling" : "rising",
            headline: headline, detail: detail
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path HavenCore`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/Weather.swift HavenCore/Tests/HavenCoreTests/WeatherStubTests.swift
git commit -m "feat: add Weather model and deterministic WeatherStub"
```

---

## Task 4: The day ledger — `LedgerEntry` + `buildLedger`

The heart of §6.5: a pure function that merges a `DayLog`'s sub-records into one time-sorted list, **excluding weather**.

**Files:**
- Create: `HavenCore/Sources/HavenCore/Ledger.swift`
- Test: `HavenCore/Tests/HavenCoreTests/LedgerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import HavenCore

@Suite struct LedgerTests {
    func day(
        factors: Factors? = nil, factorsAt: String? = nil,
        migraine: Migraine? = nil,
        symptoms: [String] = [], symptomsAt: String? = nil,
        foods: [FoodEntry] = []
    ) -> DayLog {
        DayLog(userId: "d", date: "2026-06-14", factors: factors, factorsLoggedAt: factorsAt,
               migraine: migraine, symptoms: symptoms, symptomsLoggedAt: symptomsAt, foods: foods)
    }

    @Test func emptyDayHasNoEntries() {
        #expect(buildLedger(from: day()).isEmpty)
    }

    @Test func mergesAllTypesSortedByTime() {
        let d = day(
            factors: Factors(sleepHours: 6.5, stress: .high, hydration: .low, weatherSensitive: true),
            factorsAt: "09:02",
            migraine: Migraine(had: true, severity: "moderate", time: "15:10", notes: "x"),
            symptoms: ["nausea"], symptomsAt: "14:40",
            foods: [FoodEntry(name: "Cheddar", time: "12:30", triggers: [])]
        )
        let entries = buildLedger(from: d)
        #expect(entries.map(\.time) == ["09:02", "12:30", "14:40", "15:10"])
        #expect(entries.first?.kind == .factors)
        #expect(entries.last?.kind == .migraine)
    }

    @Test func migraineExcludedWhenNotHad() {
        let d = day(migraine: Migraine(had: false, severity: "", time: "10:00", notes: ""))
        #expect(buildLedger(from: d).isEmpty)
    }

    @Test func symptomsExcludedWhenEmpty() {
        let d = day(symptoms: [], symptomsAt: "10:00")
        #expect(buildLedger(from: d).isEmpty)
    }

    @Test func factorsExcludedWhenTimestampMissing() {
        // Factors with no logged-at can't be placed on the timeline.
        let d = day(factors: Factors(sleepHours: 7, stress: .low, hydration: .mid, weatherSensitive: false),
                    factorsAt: nil)
        #expect(buildLedger(from: d).isEmpty)
    }

    @Test func eachFoodIsItsOwnEntry() {
        let d = day(foods: [
            FoodEntry(name: "A", time: "08:00", triggers: []),
            FoodEntry(name: "B", time: "12:00", triggers: []),
        ])
        let entries = buildLedger(from: d)
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.kind == .food })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HavenCore`
Expected: FAIL — `buildLedger` / `LedgerEntry` undefined.

- [ ] **Step 3: Implement `Ledger.swift`**

```swift
import Foundation

public enum LedgerKind: Sendable, Equatable { case factors, food, symptoms, migraine }

public struct LedgerEntry: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: LedgerKind
    public let time: String          // "HH:mm" — sort key
    public let title: String
    public let subtitle: String
    public let triggers: [TriggerChip]   // food only; [] otherwise
}

/// Pure §6.5 mapping: merge a day's sub-records into one time-sorted ledger.
/// Weather is never included — it is external context, never logged.
public func buildLedger(from day: DayLog) -> [LedgerEntry] {
    var entries: [LedgerEntry] = []

    if let f = day.factors, let at = day.factorsLoggedAt {
        let sleep = f.sleepHours.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0fh", f.sleepHours) : String(format: "%.1fh", f.sleepHours)
        entries.append(LedgerEntry(
            id: "factors-\(day.date)", kind: .factors, time: at,
            title: "Daily factors",
            subtitle: "Sleep \(sleep) · Stress \(f.stress.rawValue) · Water \(f.hydration.rawValue)",
            triggers: []))
    }

    for (i, food) in day.foods.enumerated() {
        entries.append(LedgerEntry(
            id: "food-\(day.date)-\(i)", kind: .food, time: food.time,
            title: food.name,
            subtitle: food.triggers.isEmpty ? "No known triggers" : "\(food.triggers.count) trigger(s)",
            triggers: food.triggers))
    }

    if !day.symptoms.isEmpty, let at = day.symptomsLoggedAt {
        entries.append(LedgerEntry(
            id: "symptoms-\(day.date)", kind: .symptoms, time: at,
            title: "Symptoms",
            subtitle: day.symptoms.joined(separator: " · "),
            triggers: []))
    }

    if let m = day.migraine, m.had {
        let notes = m.notes.isEmpty ? "" : " · \(m.notes)"
        entries.append(LedgerEntry(
            id: "migraine-\(day.date)", kind: .migraine, time: m.time,
            title: "Migraine",
            subtitle: "\(m.severity.capitalized)\(notes)",
            triggers: []))
    }

    return entries.sorted { $0.time < $1.time }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path HavenCore`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/Ledger.swift HavenCore/Tests/HavenCoreTests/LedgerTests.swift
git commit -m "feat: add day ledger builder (merges all log types, excludes weather)"
```

---

## Task 5: Streak calculation

**Files:**
- Create: `HavenCore/Sources/HavenCore/Streak.swift`
- Test: `HavenCore/Tests/HavenCoreTests/StreakTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import HavenCore

@Suite struct StreakTests {
    @Test func countsConsecutiveDaysEndingToday() {
        let dates = ["2026-06-14", "2026-06-13", "2026-06-12"]
        #expect(streak(loggedDates: dates, asOf: "2026-06-14") == 3)
    }
    @Test func stopsAtFirstGap() {
        let dates = ["2026-06-14", "2026-06-13", "2026-06-11"] // 12th missing
        #expect(streak(loggedDates: dates, asOf: "2026-06-14") == 2)
    }
    @Test func zeroWhenTodayMissing() {
        #expect(streak(loggedDates: ["2026-06-13"], asOf: "2026-06-14") == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HavenCore`
Expected: FAIL — `streak` undefined.

- [ ] **Step 3: Implement `Streak.swift`**

```swift
import Foundation

/// Consecutive days with an entry, counting back from `asOf` (a "YYYY-MM-DD").
public func streak(loggedDates: [String], asOf today: String) -> Int {
    let set = Set(loggedDates)
    let fmt = DateFormatter()
    fmt.calendar = Calendar(identifier: .gregorian)
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.dateFormat = "yyyy-MM-dd"
    guard var cursor = fmt.date(from: today) else { return 0 }

    var count = 0
    while set.contains(fmt.string(from: cursor)) {
        count += 1
        cursor = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: cursor)!
    }
    return count
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path HavenCore`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/Streak.swift HavenCore/Tests/HavenCoreTests/StreakTests.swift
git commit -m "feat: add consecutive-day streak calculation"
```

---

## Task 6: `DayDataSource` protocol + `TodayStore`

The protocol decouples the view-model from Convex so the store is testable with a fake. `TodayStore` is `@Observable` and `@MainActor`.

**Files:**
- Create: `HavenCore/Sources/HavenCore/DayDataSource.swift`
- Create: `HavenCore/Sources/HavenCore/TodayStore.swift`
- Test: `HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift`

- [ ] **Step 1: Write the failing test** (a fake source: editing factors writes, then the store reflects the new value)

```swift
import Testing
@testable import HavenCore

@MainActor
final class FakeSource: DayDataSource {
    var day: DayLog?
    var onChange: ((DayLog?) -> Void)?
    private(set) var setFactorsCalls: [(date: String, factors: Factors, at: String)] = []

    init(day: DayLog?) { self.day = day }

    func observeDay(date: String, onChange: @escaping (DayLog?) -> Void) {
        self.onChange = onChange
        onChange(day)
    }
    func setFactors(date: String, factors: Factors, loggedAt: String) async throws {
        setFactorsCalls.append((date, factors, loggedAt))
        let prev = day
        day = DayLog(userId: "d", date: date, factors: factors, factorsLoggedAt: loggedAt,
                     migraine: prev?.migraine, symptoms: prev?.symptoms ?? [],
                     symptomsLoggedAt: prev?.symptomsLoggedAt, foods: prev?.foods ?? [])
        onChange?(day)   // simulate Convex pushing the update back
    }
}

@Suite @MainActor struct TodayStoreTests {
    @Test func loadsInitialDayAndBuildsLedger() {
        let d = DayLog(userId: "d", date: "2026-06-14",
                       factors: Factors(sleepHours: 6.5, stress: .high, hydration: .low, weatherSensitive: true),
                       factorsLoggedAt: "09:02", migraine: nil, symptoms: [], symptomsLoggedAt: nil,
                       foods: [FoodEntry(name: "A", time: "08:00", triggers: [])])
        let store = TodayStore(source: FakeSource(day: d), today: "2026-06-14")
        store.start()
        #expect(store.day?.date == "2026-06-14")
        #expect(store.ledger.count == 2)               // factors + 1 food
        #expect(store.weather.headline.isEmpty == false)
    }

    @Test func editingFactorsWritesAndReflectsReactively() async throws {
        let source = FakeSource(day: DayLog(userId: "d", date: "2026-06-14", factors: nil,
                                            factorsLoggedAt: nil, migraine: nil, symptoms: [],
                                            symptomsLoggedAt: nil, foods: []))
        let store = TodayStore(source: source, today: "2026-06-14")
        store.start()
        try await store.saveFactors(Factors(sleepHours: 8, stress: .low, hydration: .mid, weatherSensitive: false),
                                     at: "10:15")
        #expect(source.setFactorsCalls.count == 1)
        #expect(store.day?.factors?.sleepHours == 8)   // pushed back through observeDay
        #expect(store.ledger.contains { $0.kind == .factors })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HavenCore`
Expected: FAIL — `DayDataSource` / `TodayStore` undefined.

- [ ] **Step 3: Implement `DayDataSource.swift`**

```swift
import Foundation

@MainActor
public protocol DayDataSource: AnyObject {
    /// Subscribe to a day's reactive updates. `onChange` fires with the current value
    /// immediately and again whenever the backend pushes a change.
    func observeDay(date: String, onChange: @escaping (DayLog?) -> Void)
    /// The M1 write path. Upserts the day's factors.
    func setFactors(date: String, factors: Factors, loggedAt: String) async throws
}
```

- [ ] **Step 4: Implement `TodayStore.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class TodayStore {
    public private(set) var day: DayLog?
    public private(set) var ledger: [LedgerEntry] = []
    public let weather: Weather
    public let today: String

    private let source: DayDataSource

    public init(source: DayDataSource, today: String) {
        self.source = source
        self.today = today
        self.weather = WeatherStub.weather(for: today)
    }

    public func start() {
        source.observeDay(date: today) { [weak self] day in
            guard let self else { return }
            self.day = day
            self.ledger = day.map(buildLedger(from:)) ?? []
        }
    }

    /// "HH:mm" for now — the ledger timestamp for a fresh edit.
    public static func nowHM(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }

    public func saveFactors(_ factors: Factors, at time: String? = nil) async throws {
        try await source.setFactors(date: today, factors: factors, loggedAt: time ?? Self.nowHM())
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --package-path HavenCore`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add HavenCore/Sources/HavenCore/DayDataSource.swift HavenCore/Sources/HavenCore/TodayStore.swift HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift
git commit -m "feat: add DayDataSource protocol and reactive TodayStore"
```

---

## Task 7: Wire `HavenCore` + `convex-swift` into the app project

**Files:**
- Modify: `Haven/project.yml`

- [ ] **Step 1: Edit `Haven/project.yml`** — add the local `HavenCore` package, the remote `convex-swift` package, and both as dependencies of the `Haven` target.

Replace the `packages:` and `targets.Haven.dependencies:` sections so they read:

```yaml
packages:
  HavenDesignSystem:
    path: ../HavenDesignSystem
  HavenCore:
    path: ../HavenCore
  convex-swift:
    url: https://github.com/get-convex/convex-swift
    from: 0.5.0
targets:
  Haven:
    type: application
    platform: iOS
    sources: [Sources]
    dependencies:
      - package: HavenDesignSystem
      - package: HavenCore
      - package: convex-swift
        product: ConvexMobile
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.haven.Haven
        GENERATE_INFOPLIST_FILE: "YES"
        INFOPLIST_KEY_UILaunchScreen_Generation: "YES"
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "6.0"
```

- [ ] **Step 2: Regenerate and resolve packages**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine/Haven && xcodegen generate && cd ..
xcodebuild -project Haven/Haven.xcodeproj -scheme Haven \
  -destination 'generic/platform=iOS Simulator' -resolvePackageDependencies | tail -5
```
Expected: package graph resolves; `ConvexMobile`, `HavenCore`, `HavenDesignSystem` all resolve. (If `from: 0.5.0` does not resolve, run `xcodebuild ... -resolvePackageDependencies` after checking the latest tag at https://github.com/get-convex/convex-swift/tags and set `from:` to it.)

- [ ] **Step 3: Commit**

```bash
git add Haven/project.yml
git commit -m "build: add HavenCore and convex-swift to the app target"
```

---

## Task 8: `DeviceIdentity` + `ConvexService` (the ConvexMobile adapter)

`ConvexService` is the only file that imports `ConvexMobile`. It conforms to `HavenCore.DayDataSource`, translating the Combine subscription into the `onChange` callback and decoding into `DayLog`.

**Files:**
- Create: `Haven/Sources/Services/DeviceIdentity.swift`
- Create: `Haven/Sources/Services/ConvexService.swift`

> No headless unit test (it needs the network + ConvexMobile). It's covered by the simulator run in Task 14. The store logic it feeds is already tested via the fake in Task 6.

- [ ] **Step 1: Write `DeviceIdentity.swift`**

```swift
import Foundation

enum DeviceIdentity {
    /// Stable per-install id. DEBUG uses the seeded id so the simulator sees demo data.
    static var current: String {
        #if DEBUG
        return "sim-device"
        #else
        let key = "haven.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
        #endif
    }
}
```

- [ ] **Step 2: Write `ConvexService.swift`** (deployment URL from P2 Task 7 Step 2)

```swift
import Foundation
import Combine
import ConvexMobile
import HavenCore

@MainActor
final class ConvexService: DayDataSource {
    // From P2 Task 7: paste your deployment URL here (or load from Info.plist / xcconfig).
    static let deploymentURL = "https://<your-deployment>.convex.cloud"

    private let client = ConvexClient(deploymentUrl: ConvexService.deploymentURL)
    private let userId = DeviceIdentity.current
    private var cancellables: Set<AnyCancellable> = []

    func observeDay(date: String, onChange: @escaping (DayLog?) -> Void) {
        let publisher: AnyPublisher<DayLog?, ClientError> =
            client.subscribe(to: "days:getDay",
                             with: ["userId": userId, "date": date],
                             yielding: DayLog?.self)
        publisher
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { value in onChange(value) }
            .store(in: &cancellables)
    }

    func setFactors(date: String, factors: Factors, loggedAt: String) async throws {
        let args: [String: ConvexEncodable] = [
            "userId": userId,
            "date": date,
            "factors": [
                "sleepHours": factors.sleepHours,
                "stress": factors.stress.rawValue,
                "hydration": factors.hydration.rawValue,
                "weatherSensitive": factors.weatherSensitive,
            ],
            "loggedAt": loggedAt,
        ]
        let _: String? = try await client.mutation("days:setFactors", with: args)
    }
}
```

> **API verification note (do this when executing):** confirm against https://docs.convex.dev/client/swift / the package source that (a) `subscribe(to:with:yielding:)` returns `AnyPublisher<T, ClientError>`, (b) the args dictionary value type is `[String: ConvexEncodable]` (nested dicts/arrays allowed), and (c) `mutation(_:with:)` is `async throws` returning a `Decodable`. The README confirmed these shapes; pin exact symbol names if the installed version differs. If live subscriptions prove rough (spec §10 risk), fall back to a one-shot `client.query` + manual refresh after `setFactors`, keeping the `DayDataSource` interface unchanged.

- [ ] **Step 3: Verify it compiles (build the app)**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine
xcodebuild -project Haven/Haven.xcodeproj -scheme Haven \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build | tail -5
```
Expected: `** BUILD SUCCEEDED **`. (Fix symbol mismatches per the verification note before proceeding.)

- [ ] **Step 4: Commit**

```bash
git add Haven/Sources/Services
git commit -m "feat: add ConvexService adapter and device identity"
```

---

## Task 9: `TopBar` + `RiskHero`

All views consume only P1 tokens + `HavenCore` models. Build after each to keep the guard + compiler green.

**Files:**
- Create: `Haven/Sources/Today/TopBar.swift`
- Create: `Haven/Sources/Today/RiskHero.swift`

- [ ] **Step 1: Write `TopBar.swift`**

```swift
import SwiftUI
import HavenDesignSystem

struct TopBar: View {
    @Environment(\.theme) private var theme
    let dateText: String
    let streak: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Today").havenText(.screenTitle, color: theme.ink)
                Text(dateText).havenText(.meta, color: theme.inkSoft)
            }
            Spacer()
            if streak > 0 {
                HStack(spacing: Spacing.s2) {
                    Image(systemName: "flame.fill").foregroundStyle(theme.accent)
                    Text("\(streak)").havenText(.meta, color: theme.accent)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s2)
                .background(theme.streakBg, in: Capsule())
            }
        }
    }
}
```

- [ ] **Step 2: Write `RiskHero.swift`**

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct RiskHero: View {
    @Environment(\.theme) private var theme
    let weather: Weather

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("WEATHER RISK").havenText(.eyebrow, color: theme.riskInk)
            Text(weather.headline).havenText(.riskWord, color: theme.risk)
            gauge
            Text(weather.detail).havenText(.body, color: theme.riskInk)
        }
        .padding(Spacing.s7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.riskBg, in: RoundedRectangle(cornerRadius: Radius.xxl))
    }

    private var gauge: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(i < weather.bars ? theme.risk : theme.track)
                    .frame(height: Spacing.s3)
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify both compile**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && cd Haven && xcodegen generate && cd ..
xcodebuild -project Haven/Haven.xcodeproj -scheme Haven -destination 'generic/platform=iOS Simulator' build | tail -3
```
Expected: `** BUILD SUCCEEDED **`. (Regenerating picks up the new source files.)

- [ ] **Step 4: Commit**

```bash
git add Haven/Sources/Today/TopBar.swift Haven/Sources/Today/RiskHero.swift
git commit -m "feat: add TopBar and RiskHero Today views"
```

---

## Task 10: `FactorRings` + `FactorEditor` (the write path)

Three rings; tapping opens a minimal editor whose Save calls `store.saveFactors`.

**Files:**
- Create: `Haven/Sources/Today/FactorRings.swift`

- [ ] **Step 1: Write `FactorRings.swift`**

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct FactorRings: View {
    @Environment(\.theme) private var theme
    let factors: Factors?
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s4) {
            ring("Sleep", level: sleepLevel, value: sleepText)
            ring("Stress", level: factors?.stress ?? .mid, value: (factors?.stress ?? .mid).rawValue.capitalized)
            ring("Water", level: invert(factors?.hydration ?? .mid), value: (factors?.hydration ?? .mid).rawValue.capitalized)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    private var sleepLevel: Level {
        guard let h = factors?.sleepHours else { return .mid }
        return h >= 7.5 ? .low : (h >= 6 ? .mid : .high)   // less sleep → higher risk
    }
    private var sleepText: String {
        guard let h = factors?.sleepHours else { return "—" }
        return h.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0fh", h) : String(format: "%.1fh", h)
    }
    // Hydration: "low" water is high risk, so invert for the color scale.
    private func invert(_ l: Level) -> Level { l == .low ? .high : (l == .high ? .low : .mid) }

    private func ring(_ label: String, level: Level, value: String) -> some View {
        VStack(spacing: Spacing.s2) {
            ZStack {
                Circle().stroke(theme.track, lineWidth: Spacing.s2)
                Circle().trim(from: 0, to: fill(for: level))
                    .stroke(theme.factorColor(for: factorLevel(level)), style: StrokeStyle(lineWidth: Spacing.s2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value).havenText(.meta, color: theme.ink)
            }
            .frame(width: 64, height: 64)
            Text(label).havenText(.eyebrow, color: theme.inkFaint)
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }

    private func fill(for level: Level) -> CGFloat {
        switch level { case .low: 0.33; case .mid: 0.66; case .high: 1.0 }
    }
    // Map the risk Level onto the design system's FactorLevel.
    private func factorLevel(_ l: Level) -> FactorLevel {
        switch l { case .low: .low; case .mid: .medium; case .high: .high }
    }
}

struct FactorEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let initial: Factors?
    let onSave: (Factors) async -> Void

    @State private var sleep: Double
    @State private var stress: Level
    @State private var hydration: Level
    @State private var weatherSensitive: Bool

    init(initial: Factors?, onSave: @escaping (Factors) async -> Void) {
        self.initial = initial
        self.onSave = onSave
        _sleep = State(initialValue: initial?.sleepHours ?? 7)
        _stress = State(initialValue: initial?.stress ?? .mid)
        _hydration = State(initialValue: initial?.hydration ?? .mid)
        _weatherSensitive = State(initialValue: initial?.weatherSensitive ?? true)
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s6) {
                Text("Daily factors").havenText(.sectionHead, color: theme.ink)

                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Sleep: \(String(format: "%.1f", sleep))h").havenText(.body, color: theme.inkSoft)
                    Stepper("", value: $sleep, in: 0...12, step: 0.5).labelsHidden().tint(theme.accent)
                }
                picker("Stress", selection: $stress)
                picker("Hydration", selection: $hydration)
                Toggle(isOn: $weatherSensitive) {
                    Text("Weather sensitive").havenText(.body, color: theme.inkSoft)
                }.tint(theme.accent)

                Button {
                    Task {
                        await onSave(Factors(sleepHours: sleep, stress: stress,
                                             hydration: hydration, weatherSensitive: weatherSensitive))
                        dismiss()
                    }
                } label: {
                    Text("Save").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                Spacer()
            }
            .padding(Spacing.s6)
        }
    }

    private func picker(_ label: String, selection: Binding<Level>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(label).havenText(.eyebrow, color: theme.inkFaint)
            Picker(label, selection: selection) {
                Text("Low").tag(Level.low); Text("Mid").tag(Level.mid); Text("High").tag(Level.high)
            }.pickerStyle(.segmented)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && cd Haven && xcodegen generate && cd ..
xcodebuild -project Haven/Haven.xcodeproj -scheme Haven -destination 'generic/platform=iOS Simulator' build | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Haven/Sources/Today/FactorRings.swift
git commit -m "feat: add FactorRings and FactorEditor write path"
```

---

## Task 11: Status cards — `MigraineAlertCard` + `SummaryCard`

**Files:**
- Create: `Haven/Sources/Today/StatusCards.swift`

- [ ] **Step 1: Write `StatusCards.swift`**

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct MigraineAlertCard: View {
    @Environment(\.theme) private var theme
    let migraine: Migraine

    var body: some View {
        HStack(spacing: Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.factorHigh)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Migraine logged · \(migraine.time)").havenText(.sectionHead, color: theme.ink)
                Text("\(migraine.severity.capitalized)\(migraine.notes.isEmpty ? "" : " · \(migraine.notes)")")
                    .havenText(.meta, color: theme.inkSoft)
            }
            Spacer()
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).stroke(theme.factorHigh, lineWidth: 1))
    }
}

struct SummaryCard: View {
    @Environment(\.theme) private var theme
    let symptoms: [String]
    let factors: Factors?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Today's status").havenText(.eyebrow, color: theme.inkFaint)
            if !symptoms.isEmpty {
                FlowChips(items: symptoms)
            }
            if let f = factors {
                Text("Sleep \(String(format: "%.1f", f.sleepHours))h · Stress \(f.stress.rawValue) · Water \(f.hydration.rawValue)")
                    .havenText(.body, color: theme.inkSoft)
            }
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }
}

/// Simple wrapping chip row.
struct FlowChips: View {
    @Environment(\.theme) private var theme
    let items: [String]
    var body: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(items, id: \.self) { item in
                Text(item).havenText(.meta, color: theme.ink)
                    .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s2)
                    .background(theme.chip, in: Capsule())
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && cd Haven && xcodegen generate && cd ..
xcodebuild -project Haven/Haven.xcodeproj -scheme Haven -destination 'generic/platform=iOS Simulator' build | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Haven/Sources/Today/StatusCards.swift
git commit -m "feat: add migraine alert and summary status cards"
```

---

## Task 12: Action buttons + the ledger view

**Files:**
- Create: `Haven/Sources/Today/ActionButtons.swift`
- Create: `Haven/Sources/Today/LedgerView.swift`

- [ ] **Step 1: Write `ActionButtons.swift`** (rendered to spec; wired in M2)

```swift
import SwiftUI
import HavenDesignSystem

struct ActionButtons: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s4) {
            primary("Log a migraine", icon: "bolt.heart")
            ghost("Snap a meal", icon: "camera")
        }
    }

    private func primary(_ title: String, icon: String) -> some View {
        Button { /* wired in M2 */ } label: {
            Label(title, systemImage: icon)
                .havenText(.sectionHead, color: theme.ctaInk)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
        }
    }
    private func ghost(_ title: String, icon: String) -> some View {
        Button { /* wired in M2 */ } label: {
            Label(title, systemImage: icon)
                .havenText(.sectionHead, color: theme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(theme.hairline, lineWidth: 1))
        }
    }
}
```

- [ ] **Step 2: Write `LedgerView.swift`** (renders `[LedgerEntry]` from `HavenCore`)

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct LedgerView: View {
    @Environment(\.theme) private var theme
    let entries: [LedgerEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("Logged today").havenText(.sectionHead, color: theme.ink)
            if entries.isEmpty {
                Text("Nothing logged yet today.").havenText(.body, color: theme.inkFaint)
                    .padding(.vertical, Spacing.s5)
            } else {
                VStack(spacing: Spacing.s3) {
                    ForEach(entries) { LedgerRow(entry: $0) }
                }
            }
        }
    }
}

struct LedgerRow: View {
    @Environment(\.theme) private var theme
    let entry: LedgerEntry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            Image(systemName: icon).foregroundStyle(accent).frame(width: Spacing.s7)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text(entry.title).havenText(.body, color: theme.ink)
                Text(entry.subtitle).havenText(.meta, color: theme.inkSoft)
                if !entry.triggers.isEmpty {
                    HStack(spacing: Spacing.s2) {
                        ForEach(entry.triggers) { t in
                            Text(t.label).havenText(.eyebrow, color: theme.ink)
                                .padding(.horizontal, Spacing.s3).padding(.vertical, Spacing.s1)
                                .background(theme.factorColor(for: factorLevel(t.level)).opacity(0.2), in: Capsule())
                        }
                    }
                }
            }
            Spacer()
            Text(entry.time).havenText(.meta, color: theme.inkFaint)
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var icon: String {
        switch entry.kind {
        case .factors: "circle.grid.2x2"
        case .food: "fork.knife"
        case .symptoms: "waveform.path.ecg"
        case .migraine: "bolt.heart"
        }
    }
    private var accent: Color {
        switch entry.kind {
        case .migraine: theme.factorHigh
        case .factors: theme.accent
        default: theme.inkSoft
        }
    }
    private func factorLevel(_ l: Level) -> FactorLevel {
        switch l { case .low: .low; case .mid: .medium; case .high: .high }
    }
}
```

- [ ] **Step 3: Build to verify both compile**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && cd Haven && xcodegen generate && cd ..
xcodebuild -project Haven/Haven.xcodeproj -scheme Haven -destination 'generic/platform=iOS Simulator' build | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Haven/Sources/Today/ActionButtons.swift Haven/Sources/Today/LedgerView.swift
git commit -m "feat: add action buttons and the day ledger view"
```

---

## Task 13: Assemble `TodayScreen` and host it in `RootView`

**Files:**
- Create: `Haven/Sources/Today/TodayScreen.swift`
- Modify: `Haven/Sources/RootView.swift`

- [ ] **Step 1: Write `TodayScreen.swift`**

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct TodayScreen: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeController.self) private var controller
    @State private var store: TodayStore
    @State private var editingFactors = false

    init(store: TodayStore) { _store = State(initialValue: store) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    TopBar(dateText: prettyDate(store.today), streak: 1)
                    RiskHero(weather: store.weather)
                    FactorRings(factors: store.day?.factors) { editingFactors = true }
                    ActionButtons()
                    if let m = store.day?.migraine, m.had {
                        MigraineAlertCard(migraine: m)
                    }
                    if store.day?.factors != nil || !(store.day?.symptoms.isEmpty ?? true) {
                        SummaryCard(symptoms: store.day?.symptoms ?? [], factors: store.day?.factors)
                    }
                    LedgerView(entries: store.ledger)
                }
                .padding(Spacing.s6)
            }
            // Theme toggle kept from P1 so dark/light verification survives.
            .overlay(alignment: .bottomTrailing) {
                Button { controller.toggle() } label: {
                    Image(systemName: controller.mode == .dark ? "sun.max.fill" : "moon.fill")
                        .foregroundStyle(theme.ctaInk).padding(Spacing.s5)
                        .background(theme.ctaBg, in: Circle())
                }
                .padding(Spacing.s6)
            }
        }
        .task { store.start() }
        .sheet(isPresented: $editingFactors) {
            FactorEditor(initial: store.day?.factors) { factors in
                try? await store.saveFactors(factors)
            }
            .environment(\.theme, theme)
        }
    }

    private func prettyDate(_ ymd: String) -> String {
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        let outF = DateFormatter(); outF.dateFormat = "EEEE, MMM d"
        return inF.date(from: ymd).map(outF.string) ?? ymd
    }
}
```

- [ ] **Step 2: Replace `RootView.swift`** to host `TodayScreen` with the real service

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct RootView: View {
    @State private var store: TodayStore = {
        let service = ConvexService()
        return TodayStore(source: service, today: Self.todayString())
    }()

    var body: some View {
        TodayScreen(store: store)
    }

    static func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
```

> Note: the seed in P2 used `today = "2026-06-14"`. If the simulator's real date differs, either re-seed for the real date (`npx convex run seed:seed '{"userId":"sim-device","today":"<real-date>"}'`) or, for the demo, hardcode `Self.todayString()` to `"2026-06-14"` in DEBUG. The screen still renders (empty ledger) if no day exists.

- [ ] **Step 3: Build**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && cd Haven && xcodegen generate && cd ..
xcodebuild -project Haven/Haven.xcodeproj -scheme Haven -destination 'generic/platform=iOS Simulator' build | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run the token guard**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && ./scripts/guard-tokens.sh`
Expected: `✓ token guard passed` (all Today views use tokens only).

- [ ] **Step 5: Commit**

```bash
git add Haven/Sources/Today/TodayScreen.swift Haven/Sources/RootView.swift
git commit -m "feat: assemble Today screen wired to live Convex data"
```

---

## Task 14: Simulator verification (the M1 finish line)

> Requires P2's deployment live + seeded, and `ConvexService.deploymentURL` set to the real URL.

- [ ] **Step 1: Confirm the deployment URL is set**

Read `Haven/Sources/Services/ConvexService.swift` and confirm `deploymentURL` is the value from `.env.local` (P2 Task 7 Step 2), not the `<your-deployment>` placeholder.

- [ ] **Step 2: Ensure today's data exists for `sim-device`**

Run (use the date `RootView` will request — the real device date, or 2026-06-14 if hardcoded in DEBUG):
```bash
cd /Users/willmorphy/.superset/projects/Migraine
npx convex run seed:seed '{"userId":"sim-device","today":"2026-06-14"}'
```
Expected: `4`.

- [ ] **Step 3: Boot, build, install, launch**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine
xcrun simctl boot "iPhone 16" 2>/dev/null || true
open -a Simulator
xcodebuild -project Haven/Haven.xcodeproj -scheme Haven \
  -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug \
  -derivedDataPath /tmp/haven-dd build
xcrun simctl install booted "$(find /tmp/haven-dd -name 'Haven.app' -type d | head -1)"
xcrun simctl launch booted app.haven.Haven
```
Expected: Today renders on warm charcoal with the serif title, the amber risk hero, three factor rings, action buttons, a migraine alert card, a summary card, and a "Logged today" ledger listing factors (09:02), foods (08:15/12:30/16:05), symptoms (14:40), and the migraine (15:10) — **time-sorted**, weather absent.

- [ ] **Step 4: Verify the reactive write path**

Tap the factor rings → the editor sheet opens → change Sleep to 8.0, Stress to Low → **Save**. Expected: the sheet dismisses and the Sleep ring + the ledger's "Daily factors" row update **without a manual refresh** (Convex pushes the change back through the subscription). Confirm over CLI:
```bash
cd /Users/willmorphy/.superset/projects/Migraine
npx convex run days:getDay '{"userId":"sim-device","date":"2026-06-14"}'
```
Expected: `factors.sleepHours` is now `8`.

- [ ] **Step 5: Verify dark↔light**

Tap the sun/moon button → the entire screen re-skins to warm paper / dark ink. Tap again to return.

---

## Definition of done (P3 = M1 complete)

1. `swift test --package-path HavenCore` passes (models decode, weather stub, ledger merge/sort/exclusion, streak, store reactive write).
2. `swift test --package-path HavenDesignSystem` still passes (P1 untouched).
3. `xcodegen generate` + `xcodebuild … build` succeeds; `./scripts/guard-tokens.sh` passes (no hardcoded values across all Today views).
4. On the simulator: Today renders seeded Convex data through tokenized UI; the ledger merges all log types time-sorted (weather excluded); editing a factor writes to Convex and updates reactively; dark↔light re-skins everything.
5. This satisfies spec §9 (Definition of done) end-to-end.

---

## Self-review notes

- **Spec coverage (§6 + §6.5):** data flow (T6 store + T8 service), models (T2), view composition — TopBar/RiskHero (T9), FactorRings + minimal editor write path (T10), action buttons (T12), migraine alert + summary cards (T11), ledger (T4 logic + T12 view); §6.5 ledger rules — all four types mapped, weather excluded, factors/symptoms redundancy intentional (they appear in both cards and ledger), empty state (T12), each type an independently testable row + `[LedgerEntry]` from a pure function (T4). Streak §6.4 (T5; wired as a simple value in T13 — full multi-day streak uses `streak(loggedDates:asOf:)` once Calendar lands in M3, noted). Weather stub §5.4 (T3).
- **Type consistency:** `Level` (low/mid/high) is the single enum across models, ledger, weather, rings, and chips; it maps to P1's `FactorLevel` via the local `factorLevel(_:)` helper (low→.low, mid→.medium, high→.high) used identically in FactorRings and LedgerRow. `DayLog` field names exactly match P2's schema (`sleepHours`, `factorsLoggedAt`, `symptomsLoggedAt`, `foods[].time`, `triggers[].level`). `setFactors` args (`userId`, `date`, `factors`, `loggedAt`) match P2 Task 4 exactly.
- **Open risks (carried from spec §10):** (1) `convex-swift` subscribe/mutation symbol names — verified shapes against the docs in T8; the verification note says exactly what to confirm and the fallback (one-shot query + manual refresh behind the unchanged `DayDataSource`). (2) `from: 0.5.0` version pin — T7 says to check the latest tag if it doesn't resolve. (3) seed date vs simulator date — T13 Step 2 note + T14 Step 2 handle it. (4) Font/PostScript names are P1's concern, already verified there.
- **No placeholders:** every view, model, and test is complete. The two intentional no-ops (`ActionButtons` handlers) are explicitly "wired in M2" per spec §6.3.
```
