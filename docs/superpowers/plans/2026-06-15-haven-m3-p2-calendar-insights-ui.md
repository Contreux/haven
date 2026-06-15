# Haven M3 · Plan 2 — Calendar/Insights UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship the bottom tab bar + Calendar + Insights screens (and the read-only DayDetail), wire `getDays` into `ConvexService`, and show the real streak — so the user can navigate the app and look back over their history.

**Architecture:** A custom `RootTabView` (token-styled bottom nav + center speed-dial) hosts Today/Calendar/Insights/Weather(placeholder), all reading one shared `TodayStore`. `ConvexService` adds the `observeDays` subscription. Calendar/Insights render the pure values from M3-P1 (`store.calendar(...)`, `store.insights`, `store.streak`).

**Tech Stack:** Swift 6 / SwiftUI · HavenDesignSystem tokens · HavenCore (Insights/CalendarMonth/streak) · convex-swift · Maestro.

**Reference:** spec §6; handoff `design_handoff/prototypes/app/screens.jsx` (CalendarScreen 226, InsightsScreen 278) + `sheets.jsx` (DayDetail).

---

## Scope & dependencies
- **Depends on:** M3-P1 (getDays + store allDays/streak/insights/calendar).
- **Produces:** the navigable app with Calendar + Insights, Maestro-verified + prototype-compared.

## File structure
```
Haven/Sources/Services/ConvexService.swift   # MODIFIED: observeDays subscription
Haven/Sources/App/RootTabView.swift          # NEW: tab bar host
Haven/Sources/RootView.swift                 # MODIFIED: host RootTabView
Haven/Sources/Today/TodayScreen.swift        # MODIFIED: real streak; speed-dial moves to RootTabView
Haven/Sources/Calendar/CalendarScreen.swift  # NEW
Haven/Sources/Calendar/DayDetail.swift       # NEW
Haven/Sources/Insights/InsightsScreen.swift  # NEW
Haven/Sources/Weather/WeatherPlaceholder.swift # NEW
Haven/maestro/navigation.yaml
```

---

## Task 1: `ConvexService.observeDays`

**Files:** Modify `Haven/Sources/Services/ConvexService.swift`.

- [ ] **Step 1: Add the method** (mirrors `observeDay`, decodes `[DayLog]`):
```swift
    func observeDays(onChange: @escaping ([DayLog]) -> Void) {
        let publisher: AnyPublisher<[DayLog], ClientError> =
            client.subscribe(to: "days:getDays", with: ["userId": userId], yielding: [DayLog].self)
        publisher
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { value in onChange(value) }
            .store(in: &cancellables)
    }
```
- [ ] **Step 2: Build** (`cd Haven && xcodegen generate && cd .. && xcodebuild -project Haven/Haven.xcodeproj -scheme Haven -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -iE 'BUILD (SUCCEEDED|FAILED)|error:'`) → SUCCEEDED. Guard → pass.
- [ ] **Step 3: Commit** — `git add Haven/Sources/Services/ConvexService.swift && git commit -m "feat: subscribe to all days in ConvexService"`

---

## Task 2: `WeatherPlaceholder`

**Files:** Create `Haven/Sources/Weather/WeatherPlaceholder.swift`.

- [ ] **Step 1: Write it**
```swift
import SwiftUI
import HavenDesignSystem

struct WeatherPlaceholder: View {
    @Environment(\.theme) private var theme
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: Spacing.s4) {
                Image(systemName: "cloud.sun").imageScale(.large).foregroundStyle(theme.inkFaint)
                Text("Weather").havenText(.sectionHead, color: theme.ink)
                Text("Barometric pressure risk is coming soon.").havenText(.body, color: theme.inkSoft)
            }.padding(Spacing.s7)
        }
    }
}
```
- [ ] **Step 2: Build → SUCCEEDED, guard → pass. Commit** — `git add Haven/Sources/Weather/WeatherPlaceholder.swift && git commit -m "feat: add Weather placeholder (M4)"`

---

## Task 3: `CalendarScreen` + `DayDetail`

**Files:** Create `Haven/Sources/Calendar/CalendarScreen.swift`, `Haven/Sources/Calendar/DayDetail.swift`.

- [ ] **Step 1: Write `CalendarScreen.swift`**
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct CalendarScreen: View {
    @Environment(\.theme) private var theme
    let store: TodayStore
    @State private var year: Int
    @State private var month: Int
    @State private var openDate: String?

    init(store: TodayStore) {
        self.store = store
        let parts = store.today.split(separator: "-")
        _year = State(initialValue: Int(parts[0]) ?? 2026)
        _month = State(initialValue: Int(parts[1]) ?? 1)
    }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 7)
    private let dow = ["S", "M", "T", "W", "T", "F", "S"]
    private let months = ["January","February","March","April","May","June","July","August","September","October","November","December"]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("Calendar").havenText(.screenTitle, color: theme.ink)
                    HStack {
                        Button { step(-1) } label: { Image(systemName: "chevron.left").foregroundStyle(theme.inkSoft) }
                        Spacer()
                        Text("\(months[month-1]) \(String(year))").havenText(.sectionHead, color: theme.ink)
                        Spacer()
                        Button { step(1) } label: { Image(systemName: "chevron.right").foregroundStyle(theme.inkSoft) }
                    }
                    HStack { ForEach(0..<7, id: \.self) { i in Text(dow[i]).havenText(.eyebrow, color: theme.inkFaint).frame(maxWidth: .infinity) } }
                    LazyVGrid(columns: cols, spacing: Spacing.s2) {
                        ForEach(store.calendar(year: year, month: month).cells) { cell in
                            cellView(cell)
                        }
                    }
                    legend
                }
                .padding(Spacing.s6)
            }
        }
        .sheet(item: Binding(get: { openDate.map { IdString($0) } }, set: { openDate = $0?.value })) { id in
            DayDetail(day: store.allDays.first { $0.date == id.value }, date: id.value)
                .environment(\.theme, theme)
        }
    }

    private func step(_ d: Int) {
        var m = month + d, y = year
        if m < 1 { m = 12; y -= 1 }; if m > 12 { m = 1; y += 1 }
        month = m; year = y
    }

    @ViewBuilder private func cellView(_ cell: CalendarCell) -> some View {
        if let day = cell.day {
            Button { openDate = cell.date } label: {
                VStack(spacing: Spacing.s1) {
                    Text("\(day)").havenText(.meta, color: cell.isToday ? theme.ctaInk : theme.ink)
                    mark(cell)
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(cell.isToday ? theme.ctaBg : Color.clear, in: RoundedRectangle(cornerRadius: Radius.sm))
            }
        } else {
            Color.clear.frame(height: 44)
        }
    }

    @ViewBuilder private func mark(_ cell: CalendarCell) -> some View {
        if let sev = cell.migraineSeverity {
            Circle().stroke(severityColor(sev), lineWidth: 2).frame(width: Spacing.s4, height: Spacing.s4)
        } else if cell.mark == .food {
            Circle().fill(theme.accent).frame(width: Spacing.s2, height: Spacing.s2)
        } else if cell.mark == .symptoms {
            Circle().fill(theme.inkSoft).frame(width: Spacing.s2, height: Spacing.s2)
        } else {
            Color.clear.frame(height: Spacing.s2)
        }
    }

    private func severityColor(_ sev: String) -> Color {
        switch sev.lowercased() {
        case "severe": theme.factorColor(for: .high)
        case "mild": theme.factorColor(for: .medium)
        default: theme.accent
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            legendRow(Circle().stroke(theme.accent, lineWidth: 2).frame(width: Spacing.s4, height: Spacing.s4), "Migraine (ring = severity)")
            legendRow(Circle().fill(theme.accent).frame(width: Spacing.s2, height: Spacing.s2), "Food logged")
            legendRow(Circle().fill(theme.inkSoft).frame(width: Spacing.s2, height: Spacing.s2), "Symptoms")
        }
    }
    private func legendRow<V: View>(_ glyph: V, _ label: String) -> some View {
        HStack(spacing: Spacing.s3) { glyph; Text(label).havenText(.meta, color: theme.inkSoft) }
    }
}

struct IdString: Identifiable { let value: String; init(_ v: String) { value = v }; var id: String { value } }
```

- [ ] **Step 2: Write `DayDetail.swift`** (read-only; reuses ledger building)
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct DayDetail: View {
    @Environment(\.theme) private var theme
    let day: DayLog?
    let date: String

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    SheetHeader(title: prettyDate(date), subtitle: "Logged that day")
                    if let day {
                        if let m = day.migraine, m.had { MigraineAlertCard(migraine: m) }
                        let entries = buildLedger(from: day)
                        if entries.isEmpty {
                            Text("Nothing logged.").havenText(.body, color: theme.inkFaint)
                        } else {
                            LedgerView(entries: entries)
                        }
                    } else {
                        Text("Nothing logged.").havenText(.body, color: theme.inkFaint)
                    }
                    Spacer()
                }
                .padding(Spacing.s6)
            }
        }
    }

    private func prettyDate(_ ymd: String) -> String {
        let inF = DateFormatter(); inF.locale = Locale(identifier: "en_US_POSIX")
        inF.calendar = Calendar(identifier: .gregorian); inF.dateFormat = "yyyy-MM-dd"
        let outF = DateFormatter(); outF.dateFormat = "EEEE, MMM d"
        return inF.date(from: ymd).map(outF.string) ?? ymd
    }
}
```
> `LedgerView` is reused; it shows "Logged today" as its header — acceptable, or pass a title later. For M3 the reuse is fine (DayDetail's SheetHeader gives the date context).

- [ ] **Step 3: Build → SUCCEEDED, guard → pass.** Commit — `git add Haven/Sources/Calendar && git commit -m "feat: add CalendarScreen and DayDetail"`

---

## Task 4: `InsightsScreen`

**Files:** Create `Haven/Sources/Insights/InsightsScreen.swift`.

- [ ] **Step 1: Write it**
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct InsightsScreen: View {
    @Environment(\.theme) private var theme
    let store: TodayStore

    var body: some View {
        let r = store.insights
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("Insights").havenText(.screenTitle, color: theme.ink)
                    HStack(spacing: Spacing.s3) {
                        stat("\(r.migraineDays)", "Migraine days", theme.factorHigh)
                        stat("\(r.trackedDays)", "Days tracked", theme.ink)
                        stat("\(r.triggersSeen)", "Triggers seen", theme.accent)
                    }
                    Text("Your triggers").havenText(.sectionHead, color: theme.ink)
                    Text("Ranked by how often they land on a migraine day.").havenText(.meta, color: theme.inkSoft)
                    if r.ranked.isEmpty {
                        Text("Log a few meals to start building your trigger ranking.")
                            .havenText(.body, color: theme.inkFaint).padding(.vertical, Spacing.s5)
                    } else {
                        ForEach(Array(r.ranked.enumerated()), id: \.element.id) { i, t in
                            triggerRow(rank: i + 1, stat: t, maxTotal: r.ranked.map(\.total).max() ?? 1)
                        }
                    }
                    noteCard
                }
                .padding(Spacing.s6)
            }
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Text(value).havenText(.riskWord, color: color)
            Text(label).havenText(.meta, color: theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s4).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private func triggerRow(rank: Int, stat t: TriggerStat, maxTotal: Int) -> some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            Text("\(rank)").havenText(.sectionHead, color: theme.inkFaint).frame(width: Spacing.s7)
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack {
                    Text(t.name).havenText(.body, color: theme.ink)
                    Spacer()
                    Text(t.onMigraine > 0 ? "\(t.onMigraine) migraine\(t.onMigraine == 1 ? "" : "s")" : "no overlap")
                        .havenText(.meta, color: t.onMigraine > 0 ? theme.factorHigh : theme.inkSoft)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.track)
                        Capsule().fill(theme.factorColor(for: factorLevel(t.level)))
                            .frame(width: geo.size.width * CGFloat(t.total) / CGFloat(max(1, maxTotal)))
                    }
                }.frame(height: Spacing.s2)
                Text("Eaten \(t.total) time\(t.total == 1 ? "" : "s")").havenText(.meta, color: theme.inkFaint)
            }
        }
        .padding(Spacing.s4).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: Spacing.s2) { Image(systemName: "sparkles").foregroundStyle(theme.accent); Text("A note on patterns").havenText(.sectionHead, color: theme.ink) }
            Text("This is a list of hypotheses to test, not conclusions. Triggers stack — a food often only sets things off alongside poor sleep, stress or dehydration. Look for patterns over weeks, not single days.")
                .havenText(.body, color: theme.inkSoft)
        }
        .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }

    private func factorLevel(_ l: Level) -> FactorLevel {
        switch l { case .low: .low; case .mid: .medium; case .high: .high }
    }
}
```
- [ ] **Step 2: Build → SUCCEEDED, guard → pass.** Commit — `git add Haven/Sources/Insights && git commit -m "feat: add InsightsScreen with trigger ranking"`

---

## Task 5: `RootTabView` + refactor `RootView`/`TodayScreen`

**Files:** Create `Haven/Sources/App/RootTabView.swift`; Modify `Haven/Sources/RootView.swift`, `Haven/Sources/Today/TodayScreen.swift`.

The speed-dial + logger sheets move up to `RootTabView` so they're available on every tab; `TodayScreen` loses its overlay speed-dial and gains a real streak.

- [ ] **Step 1: Write `RootTabView.swift`** (hosts screens + bottom nav + center speed-dial + the logger sheets)
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct RootTabView: View {
    @Environment(\.theme) private var theme
    @State private var store: TodayStore
    @State private var tab: Tab = .today
    @State private var activeSheet: LoggerKind?
    @State private var dialOpen = false

    enum Tab { case today, calendar, insights, weather }

    init(store: TodayStore) { _store = State(initialValue: store) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .today: TodayScreen(store: store, onEditFactors: { activeSheet = .factors })
                case .calendar: CalendarScreen(store: store)
                case .insights: InsightsScreen(store: store)
                case .weather: WeatherPlaceholder()
                }
            }
            bottomNav
        }
        .task { store.start() }
        .sheet(item: $activeSheet) { kind in sheet(for: kind).environment(\.theme, theme) }
        .overlay(alignment: .bottomTrailing) {
            SpeedDial(isOpen: $dialOpen) { kind in activeSheet = kind }
                .padding(.trailing, Spacing.s6).padding(.bottom, 84)
        }
    }

    private var bottomNav: some View {
        HStack {
            navButton(.today, system: "\(Calendar.current.component(.day, from: Date()))".count <= 2 ? "calendar.day.timeline.left" : "house")
            navButton(.calendar, system: "calendar")
            Spacer().frame(width: 56) // center speed-dial gap
            navButton(.insights, system: "chart.bar")
            navButton(.weather, system: "cloud")
        }
        .padding(.horizontal, Spacing.s7).padding(.vertical, Spacing.s4)
        .background(theme.tabbarBg)
        .accessibilityIdentifier("bottom-nav")
    }

    private func navButton(_ t: Tab, system: String) -> some View {
        Button { tab = t } label: {
            Image(systemName: system)
                .foregroundStyle(tab == t ? theme.tabActiveInk : theme.inkFaint)
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("tab-\(label(t))")
    }
    private func label(_ t: Tab) -> String { switch t { case .today: "today"; case .calendar: "calendar"; case .insights: "insights"; case .weather: "weather" } }

    @ViewBuilder private func sheet(for kind: LoggerKind) -> some View {
        switch kind {
        case .migraine: MigraineSheet(existing: store.day?.migraine, onSave: { try? await store.saveMigraine($0) }, onRemove: { try? await store.removeMigraine() })
        case .symptom: SymptomSheet(existing: store.day?.symptoms ?? []) { try? await store.saveSymptoms($0) }
        case .factors: FactorsSheet(initial: store.day?.factors) { try? await store.saveFactors($0) }
        case .food: FoodCaptureSheet(analyze: { await store.analyze($0) }) { food, imageData in await saveFood(food, imageData) }
        }
    }
    private func saveFood(_ food: FoodEntry, _ imageData: Data?) async {
        var entry = food
        if let imageData, let service = store.source as? ConvexService, let id = try? await service.uploadImage(imageData) {
            entry = FoodEntry(name: food.name, time: food.time, triggers: food.triggers, note: food.note, imageId: id)
        }
        try? await store.saveFood(entry)
    }
}
```
> The day-number tab icon is simplified to an SF Symbol here (the prototype shows the date number); a numbered glyph can come later. Center speed-dial stays a bottom-trailing overlay above the nav for M3 (simpler than embedding in the bar); the design's centered "+" is a fidelity refinement noted for later.

- [ ] **Step 2: Modify `TodayScreen.swift`** — remove its own speed-dial overlay + sheet presentation + `activeSheet`/`dialOpen` state (now owned by RootTabView); accept `onEditFactors`; use `store.streak`:
  - Change the struct to `init(store:onEditFactors:)`, store the closure.
  - `TopBar(dateText: prettyDate(store.today), streak: store.streak)` (real streak).
  - The "Today's factors" Edit button and `FactorRings` tap call `onEditFactors()`.
  - Remove the `.overlay { SpeedDial ... }`, the `.sheet(item:)`, the `sheet(for:)`/`saveFood` helpers, and `@State activeSheet/dialOpen` (moved to RootTabView). Keep `.task { }` removal — `start()` is now called by RootTabView, so delete TodayScreen's `.task { store.start() }`.
  - `ActionButtons(onLogMigraine: { onEditFactors() /* placeholder */ }, ...)` — NO: action buttons need migraine/food. Instead accept three closures or a single `onLogger: (LoggerKind) -> Void`. Simplify: change `TodayScreen.init(store:onLogger:)` where `onLogger(.migraine)` etc., and RootTabView passes `{ activeSheet = $0 }`. Then ActionButtons → `onLogMigraine: { onLogger(.migraine) }`, `onSnapMeal: { onLogger(.food) }`; Edit/rings → `onLogger(.factors)`.

  Concretely, `TodayScreen` signature becomes `init(store: TodayStore, onLogger: @escaping (LoggerKind) -> Void)`, and RootTabView calls `TodayScreen(store: store, onLogger: { activeSheet = $0 })`.

- [ ] **Step 3: Modify `RootView.swift`** — host `RootTabView` instead of `TodayScreen`:
```swift
struct RootView: View {
    @State private var store: TodayStore = {
        let service = ConvexService()
        return TodayStore(source: service, today: Self.todayString())
    }()
    var body: some View { RootTabView(store: store) }
    static func todayString() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
```

- [ ] **Step 4: Build → SUCCEEDED, guard → pass.** (Resolve any wiring mismatch so `onLogger` flows; do NOT change tokens/APIs.) Commit — `git add Haven/Sources/App/RootTabView.swift Haven/Sources/RootView.swift Haven/Sources/Today/TodayScreen.swift && git commit -m "feat: add RootTabView nav hosting Today/Calendar/Insights/Weather"`

---

## Task 6: Maestro + fidelity

**Files:** Create `Haven/maestro/navigation.yaml`.

- [ ] **Step 1: Seed current date + build/install/launch** (reuse the M2 sequence; seed `today=$(date +%Y-%m-%d)`).
- [ ] **Step 2: Write `navigation.yaml`**
```yaml
appId: app.haven.Haven
---
- launchApp
- assertVisible: "Today"
- tapOn:
    id: "tab-calendar"
- assertVisible: "Calendar"
- takeScreenshot: m3-calendar
- tapOn:
    id: "tab-insights"
- assertVisible: "Insights"
- assertVisible: "Your triggers"
- takeScreenshot: m3-insights
- tapOn:
    id: "tab-today"
- assertVisible: "Today's factors"
```
- [ ] **Step 3: Run** — `maestro test Haven/maestro/navigation.yaml` → all COMPLETED, exit 0. Read `m3-calendar.png` + `m3-insights.png`.
- [ ] **Step 4: Fidelity** — render the prototype Calendar + Insights (Chrome headless against the served prototype: the prototype starts on Today; to reach Calendar/Insights, drive it — or compare structure against `screens.jsx`). Reconcile obvious divergences (grid spacing, ring/dot marks, stat row, ranked bars). Fix in the SwiftUI if a clear gap exists.
- [ ] **Step 5: Commit** — `git add Haven/maestro/navigation.yaml && git commit -m "test: add M3 navigation Maestro flow"`

---

## Definition of done (M3-P2 = M3 complete)
1. Bottom nav switches Today/Calendar/Insights/Weather; center "+" still opens loggers from any tab.
2. Calendar shows the current month with migraine rings + food/symptom dots; tapping a day opens DayDetail.
3. Insights shows the 3 stats + the ranked trigger list from seeded data.
4. TopBar shows the real streak.
5. All suites green; guard clean; app builds + runs; Maestro green; screens reasonably match the prototype.

## Self-review notes
- **Spec coverage (§6):** RootTabView (T5), CalendarScreen+DayDetail (T3), InsightsScreen (T4), WeatherPlaceholder (T2), observeDays (T1), real streak (T5). DayDetail read-only (reuses LedgerView).
- **Type consistency:** screens read `store.calendar(year:month:)`, `store.insights`, `store.streak`, `store.allDays` (M3-P1). `LoggerKind`/the four sheets reused from M2. `severityColor` compares case-insensitively (seed lowercase vs MigraineSheet capitalized).
- **Risks:** (1) moving the speed-dial + sheets to RootTabView means TodayScreen no longer owns them — verify the loggers still present from Today and the other tabs. (2) `start()` now called once by RootTabView (not TodayScreen) — ensure it isn't called twice. (3) the numbered day-tab glyph + centered "+" are fidelity refinements noted for later; M3 uses SF Symbols + a bottom-trailing speed-dial.
