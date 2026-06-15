# Haven — Milestone 3: Calendar + Insights (Design Spec)

**Date:** 2026-06-15
**Status:** Approved for planning (standing authorization)
**Milestone:** 3 of 5

---

## 1. Goal

Give the user the two "look back" surfaces — a **Calendar** to see their month at a glance (which days had a migraine, food, symptoms) and **Insights** that rank their food triggers by how often they coincide with migraine days. This milestone also lands the **bottom tab bar** (deferred from M1, since Today was the only screen) and wires the **real streak** (deferred from M1).

### Non-goals
Real barometric weather (M4 — the Weather tab is a placeholder here) · onboarding/paywall/auth (M5) · editing past days from the calendar (DayDetail is read-only in M3).

---

## 2. Confirmed decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Navigation | **Custom bottom tab bar** (not `TabView`) to match the design's center speed-dial + token styling. 5 slots: Today / Calendar / [+] / Insights / Weather. |
| 2 | Weather tab (M3) | **Placeholder** ("Weather — coming soon"); full screen + real API is M4. |
| 3 | Multi-day data | New Convex query **`getDays(userId)`** returns all of the user's day docs. Calendar, Insights, and streak all consume it. (Pagination deferred — fine at M3 scale.) |
| 4 | Aggregation | **Pure HavenCore functions** over `[DayLog]`: `Insights.compute`, `CalendarMonth.build`, `streak` (already exists). Headless-tested. |
| 5 | Calendar marks | Per the prototype: migraine = **ring** colored by severity (Severe→factorHigh, Mild→factorMid, Moderate→accent); food logged = **dot** (accent); symptoms-only = **dot** (inkSoft). Today cell highlighted. |
| 6 | DayDetail | **Read-only** bottom sheet (date, migraine alert, food list, factors summary). Editing past days is a later enhancement. |
| 7 | Real streak | `TodayStore` loads all days → `streak(loggedDates:asOf:)` → TopBar shows the real count. |

---

## 3. Architecture overview

```
RootTabView (custom bottom nav + center speed-dial)
├── TodayScreen     (M1/M2 — now gets real streak)
├── CalendarScreen  ── tap day ──> DayDetail sheet
├── InsightsScreen
└── WeatherPlaceholder (M4)

TodayStore (extended): allDays: [DayLog]  ← getDays subscription
        │                         │
        ▼                         ▼
   streak(loggedDates)     Insights.compute(allDays)   CalendarMonth.build(allDays, month)
   (real TopBar streak)    (stats + ranked triggers)   (cells with marks)
```

`getDays` is a second Convex subscription (alongside `getDay`) that feeds `allDays`. All aggregation is pure and lives in HavenCore (testable without Convex/UI). The calendar/insights screens are tokenized SwiftUI reading derived values off the store.

---

## 4. Backend — Convex

| Kind | Name | Purpose |
|---|---|---|
| query | `getDays(userId)` | All day docs for the device, used by Calendar/Insights/streak. Returns `[DayLog]` sorted by date. |

`convex/days.ts`:
```ts
export const getDays = query({
  args: { userId: v.string() },
  handler: async (ctx, { userId }) =>
    await ctx.db.query("days").withIndex("by_user_date", q => q.eq("userId", userId)).collect(),
});
```
Covered by `convex-test` (returns all the device's days; scoped; sorted ascending by the index).

---

## 5. HavenCore — pure aggregation

### 5.1 Insights (`Insights.swift`)
```swift
public struct TriggerStat: Sendable, Equatable, Identifiable {
    public let name: String          // trigger label
    public let level: Level
    public let total: Int            // times eaten
    public let onMigraine: Int       // times on a migraine day
    public var id: String { name }
}
public struct InsightsResult: Sendable, Equatable {
    public let migraineDays: Int
    public let trackedDays: Int
    public let triggersSeen: Int
    public let ranked: [TriggerStat]  // sorted onMigraine desc, then total desc
}
public enum Insights { public static func compute(_ days: [DayLog]) -> InsightsResult }
```
Rules (ported from the prototype): a day is "tracked" if it has foods OR factors OR symptoms; "migraine day" if `migraine?.had`. For each food trigger, count `total` and `onMigraine` (when that day had a migraine). Rank by `onMigraine` desc then `total` desc. `triggersSeen` = distinct trigger labels.

### 5.2 Calendar month (`CalendarMonth.swift`)
```swift
public enum DayMark: Sendable, Equatable { case none, food, symptoms }   // dot type
public struct CalendarCell: Sendable, Equatable, Identifiable {
    public let id: Int               // 1...daysInMonth (0 = leading blank uses negative ids)
    public let day: Int?             // nil = blank leading cell
    public let date: String?         // "YYYY-MM-DD"
    public let migraineSeverity: String?   // nil if none; else "Mild"/"Moderate"/"Severe"
    public let mark: DayMark
    public let isToday: Bool
}
public struct CalendarMonth: Sendable, Equatable {
    public let year: Int; public let month: Int  // 1-12
    public let cells: [CalendarCell]              // leading blanks + day cells
    public static func build(days: [DayLog], year: Int, month: Int, today: String) -> CalendarMonth
}
```
Pure: builds the grid (leading blanks for the first weekday, then 1…daysInMonth), looks up each date in `days`, sets `migraineSeverity` (if `migraine?.had`), `mark` (.food if foods non-empty, else .symptoms if symptoms non-empty, else .none), `isToday`. UTC/gregorian date math (consistent with `streak`).

### 5.3 Streak wiring
`TodayStore` already has `streak` available; M3 computes it from `allDays`' dates: `streak(loggedDates: allDays.map(\.date), asOf: today)` exposed as `store.streak`.

### 5.4 Store extension
`TodayStore` gains `allDays: [DayLog]` (from a `getDays` subscription via a new `DayDataSource.observeDays`), plus computed `streak: Int`, `insights: InsightsResult`, and `calendar(year:month:) -> CalendarMonth`. Tested via the fake.

---

## 6. Client — screens

### 6.1 RootTabView (`RootTabView.swift`)
Hosts the 4 screens + a custom bottom nav (token-styled): Today (shows today's date number), Calendar (cal icon), center **"+"** (the existing SpeedDial), Insights (chart icon), Weather (cloud icon). Selected tab tinted `tabActiveInk`/`tabActiveBg`; bar background `tabbarBg`. Replaces `RootView`'s direct `TodayScreen` host. The speed-dial moves from a floating overlay into the center nav slot.

### 6.2 CalendarScreen (`CalendarScreen.swift`)
Month bar (chevron prev/next + "Month Year"), weekday header (S M T W T F S), 7-col grid of `CalendarCell`s. Each cell: day number; a migraine ring (stroked circle in severity color) when present; a small dot (food=accent / symptoms=inkSoft) otherwise; today cell highlighted (filled/bordered). Legend row. Tap a non-blank cell → DayDetail sheet for that date.

### 6.3 DayDetail (`DayDetail.swift`)
Read-only sheet: pretty date, migraine alert card (if had), food list (FoodCard-style rows with trigger chips), factors summary. Reuses `LedgerView`/row styling or a compact variant.

### 6.4 InsightsScreen (`InsightsScreen.swift`)
Stat row (3 big stats: migraine days [factorHigh], days tracked [ink], triggers seen [accent]). "Your triggers" header + subtitle. Ranked list: rank number, trigger name, "{n} migraines" / "no overlap" tag, a frequency bar (width ∝ total/maxTotal, colored by level), "Eaten {n} times". Empty state. "A note on patterns" info card.

### 6.5 WeatherPlaceholder
Minimal centered "Weather — coming soon" using tokens. Replaced in M4.

---

## 7. Testing strategy

| Layer | Test |
|---|---|
| Convex | `getDays` returns all device days, scoped, ascending. |
| HavenCore | `Insights.compute` (tracked/migraine day counts, trigger total/onMigraine, ranking, distinct count, empty); `CalendarMonth.build` (leading blanks, day lookup, severity/mark/today, month rollover); `streak` (already); store `allDays`/`streak`/`insights` via fake. |
| UI (Maestro) | switch tabs; calendar renders the month + a migraine ring; tap a day opens DayDetail; insights shows the ranked triggers. |
| Fidelity | Calendar + Insights screenshots compared to the prototype (Chrome-headless render). |

---

## 8. Definition of done
1. Bottom tab bar switches between Today / Calendar / Insights / Weather(placeholder); center "+" still opens the loggers.
2. Calendar shows the current month with correct marks; tapping a day opens its DayDetail.
3. Insights ranks the seeded triggers correctly (e.g. aged cheese / red wine high on migraine days).
4. TopBar streak shows the real consecutive-day count.
5. All suites pass (Convex, HavenCore, design-system); guard clean; app builds + runs; Maestro flow green; screens match the prototype.

---

## 9. Open risks
- **Two subscriptions** (`getDay` + `getDays`) on one store — ensure both update `@Observable` state on main; the existing ConvexService subscription pattern extends cleanly (store an extra `AnyCancellable`).
- **Custom tab bar vs SpeedDial overlay** — the speed-dial currently lives as a TodayScreen overlay; M3 moves it into the shared nav so it's available on every tab. Refactor carefully so the loggers still present (sheets move up to RootTabView or stay per-screen via a shared binding).
- **Calendar date math** — reuse UTC/gregorian like `streak`/`seed` to avoid off-by-one across month boundaries.
