# Haven M4 — Weather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Real barometric-pressure risk from Open-Meteo (no API key), with the full Weather screen, degrading to the stub offline.

**Architecture:** A `fetchWeather` Convex action calls Open-Meteo and computes swing/level/trend; the Swift `Weather` model (now Codable, +swing/+pressureTrend) decodes it; `TodayStore.loadWeather()` is two-tier (action → stub fallback). The WeatherScreen + Today's RiskHero read `store.weather`.

**Tech Stack:** Convex (Node action, fetch) · Open-Meteo · Swift 6 / SwiftUI · HavenCore.

**Reference:** spec `docs/superpowers/specs/2026-06-15-haven-m4-weather-design.md`; handoff `screens.jsx` WeatherScreen (340).

---

## Task 1: Extend `Weather` model + stub

**Files:** Modify `HavenCore/Sources/HavenCore/Weather.swift`; Test `HavenCore/Tests/HavenCoreTests/WeatherStubTests.swift`.

- [ ] **Step 1: Add failing test** (append to WeatherStubTests)
```swift
    @Test func weatherDecodesActionShape() throws {
        let json = #"{"level":"high","bars":3,"swing":9,"tempSwing":7,"humidity":71,"temp":17,"trend":"falling","headline":"Pressure dropping 9 hPa","detail":"with a 7° swing","pressureTrend":[1015.6,1014.9,1013.2,1011.5]}"#
        let w = try JSONDecoder().decode(Weather.self, from: Data(json.utf8))
        #expect(w.swing == 9)
        #expect(w.level == .high)
        #expect(w.pressureTrend.count == 4)
    }
    @Test func stubPopulatesSwingAndTrend() {
        let w = WeatherStub.weather(for: "2026-06-15")
        #expect(w.swing >= 0)
        #expect(w.pressureTrend.isEmpty == false)
    }
```

- [ ] **Step 2: Run → FAIL** — `swift test --package-path HavenCore`.

- [ ] **Step 3: Edit `Weather.swift`** — add the two fields + `Codable`, and populate them in the stub:
```swift
public struct Weather: Codable, Sendable, Equatable {
    public let level: Level
    public let bars: Int
    public let swing: Int            // pressure swing (hPa)
    public let tempSwing: Int
    public let humidity: Int
    public let temp: Int
    public let trend: String
    public let headline: String
    public let detail: String
    public let pressureTrend: [Double]
}
```
In `WeatherStub.weather(for:)`, add to the returned `Weather(...)`: `swing: bars * 3, pressureTrend: (0..<8).map { 1015 - Double(i: $0, seed: seed) }` — concretely compute a short descending series:
```swift
        let pressureTrend = (0..<8).map { i in 1015.0 - Double((seed + i) % 6) - Double(i) * 0.4 }
        return Weather(
            level: level, bars: bars, swing: bars * 3,
            tempSwing: 4 + (seed % 6), humidity: 55 + (seed % 30),
            temp: 14 + (seed % 12), trend: seed % 2 == 0 ? "falling" : "rising",
            headline: headline, detail: detail, pressureTrend: pressureTrend)
```
(Keep the existing `level`/`bars`/`headline`/`detail` logic; only add `swing` + `pressureTrend` + `Codable`.)

- [ ] **Step 4: Run → PASS.** (Other suites that construct `Weather` — none outside the stub — stay green.)
- [ ] **Step 5: Commit** — `git add HavenCore/Sources/HavenCore/Weather.swift HavenCore/Tests/HavenCoreTests/WeatherStubTests.swift && git commit -m "feat: extend Weather with swing/pressureTrend + Codable"`

---

## Task 2: `fetchWeather` action

**Files:** Create `convex/weather.ts`; Test `convex/weather.test.ts`.

- [ ] **Step 1: Write failing test** (no network — assert it's callable and returns the right shape, OR throws cleanly; since the action does a live fetch, test that it returns an object with `level` when the network is available, else tolerate a throw)
```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";

const modules = import.meta.glob("./**/*.ts");

test("fetchWeather returns a weather shape or throws (network-dependent)", async () => {
  const t = convexTest(schema, modules);
  try {
    const w = await t.action(api.weather.fetchWeather, { lat: 51.51, lon: -0.13 });
    expect(["low", "mid", "high"]).toContain(w.level);
    expect(Array.isArray(w.pressureTrend)).toBe(true);
  } catch (e) {
    // edge-runtime has no real network — a throw is acceptable; the client falls back to the stub.
    expect(e).toBeTruthy();
  }
});
```

- [ ] **Step 2: Run → FAIL** (`api.weather.fetchWeather` undefined).

- [ ] **Step 3: Implement `convex/weather.ts`**
```typescript
"use node";
import { action } from "./_generated/server";
import { v } from "convex/values";

export const fetchWeather = action({
  args: { lat: v.number(), lon: v.number() },
  handler: async (_ctx, { lat, lon }) => {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
      `&hourly=surface_pressure,temperature_2m,relative_humidity_2m,wind_speed_10m&forecast_days=1`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Open-Meteo ${res.status}`);
    const data = await res.json();
    const h = data?.hourly;
    if (!h || !Array.isArray(h.surface_pressure)) throw new Error("bad weather shape");

    const press: number[] = h.surface_pressure.slice(0, 8);
    const temps: number[] = h.temperature_2m.slice(0, 8);
    const swing = Math.round(Math.max(...press) - Math.min(...press));
    const tempSwing = Math.round(Math.max(...temps) - Math.min(...temps));
    const temp = Math.round(temps[0]);
    const humidity = Math.round(h.relative_humidity_2m?.[0] ?? 0);
    const falling = press[press.length - 1] < press[0];
    const trend = Math.abs(press[press.length - 1] - press[0]) < 1 ? "steady" : (falling ? "falling" : "rising");

    let level: "low" | "mid" | "high" = "low", bars = 1, headline = "Calm pressure";
    if (swing >= 8) { level = "high"; bars = 3; headline = `Pressure dropping ${swing} hPa`; }
    else if (swing >= 4) { level = "mid"; bars = 2; headline = "Shifting front"; }
    const detail = swing >= 4
      ? `with a ${tempSwing}° swing — your strongest signals are active.`
      : `Stable pressure with a ${tempSwing}° temp swing — low trigger risk.`;

    return { level, bars, swing, tempSwing, humidity, temp, trend, headline, detail,
             pressureTrend: press.map((p) => Math.round(p * 10) / 10) };
  },
});
```

- [ ] **Step 4: Run → PASS** (returns a shape if Open-Meteo is reachable from the test runtime, else the catch tolerates a throw). Run `npm test` (full suite).
- [ ] **Step 5: Commit** — `git add convex/weather.ts convex/weather.test.ts && git commit -m "feat: add fetchWeather action (Open-Meteo, no key)"`. Deploy: `npx convex dev --once 2>&1 | tail -6` (commit `_generated` if changed). Verify live: `npx convex run weather:fetchWeather '{"lat":51.51,"lon":-0.13}'` → prints a weather object.

---

## Task 3: `DayDataSource.fetchWeather` + `ConvexService` + `TodayStore.loadWeather` (two-tier)

**Files:** Modify `HavenCore/.../DayDataSource.swift`, `TodayStore.swift`; `HavenCore/Tests/.../TodayStoreTests.swift`; `Haven/Sources/Services/ConvexService.swift`. **This is the build-restoration task — implement ConvexService right after the protocol grows.**

- [ ] **Step 1: Extend the test** — add to `FakeSource`:
```swift
    var weatherResult: Weather?
    var weatherShouldThrow = false
    func fetchWeather(lat: Double, lon: Double) async throws -> Weather {
        if weatherShouldThrow { throw NSError(domain: "x", code: 1) }
        return weatherResult ?? WeatherStub.weather(for: "2026-06-15")
    }
```
Add a test:
```swift
    @Test func loadWeatherUsesActionThenFallsBack() async {
        let src = FakeSource(day: nil)
        src.weatherResult = Weather(level: .high, bars: 3, swing: 9, tempSwing: 7, humidity: 70, temp: 17, trend: "falling", headline: "Pressure dropping 9 hPa", detail: "x", pressureTrend: [1015, 1013, 1011])
        let store = TodayStore(source: src, today: "2026-06-15")
        await store.loadWeather()
        #expect(store.weather.swing == 9)        // action path
        src.weatherShouldThrow = true
        await store.loadWeather()
        #expect(store.weather.headline.isEmpty == false)  // fell back to stub, still valid
    }
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Extend `DayDataSource.swift`** — add:
```swift
    func fetchWeather(lat: Double, lon: Double) async throws -> Weather
```

- [ ] **Step 4: Edit `TodayStore.swift`** — make `weather` mutable + add `loadWeather`, call it from `start()`:
```swift
    public private(set) var weather: Weather

    // in init: keep `self.weather = WeatherStub.weather(for: today)` as the initial value.
    // Default location (M5 onboarding will set a real one):
    public var location: (lat: Double, lon: Double) = (51.51, -0.13)

    public func loadWeather() async {
        do { weather = try await source.fetchWeather(lat: location.lat, lon: location.lon) }
        catch { weather = WeatherStub.weather(for: today) }
    }
    // in start(), after the subscriptions: Task { await loadWeather() }
```
> `weather` changes from `let` to `private(set) var`; the initial stub value stays so the hero renders immediately, then `loadWeather()` updates it reactively.

- [ ] **Step 5: Implement `ConvexService.fetchWeather`** (restores conformance):
```swift
    func fetchWeather(lat: Double, lon: Double) async throws -> Weather {
        try await client.action("weather:fetchWeather", with: ["lat": lat, "lon": lon])
    }
```
- [ ] **Step 6: Run `swift test --package-path HavenCore` → PASS; build the app** (`cd Haven && xcodegen generate && cd .. && xcodebuild ... build` → SUCCEEDED) — conformance restored. Guard → pass.
- [ ] **Step 7: Commit** — `git add HavenCore/Sources/HavenCore/DayDataSource.swift HavenCore/Sources/HavenCore/TodayStore.swift HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift Haven/Sources/Services/ConvexService.swift && git commit -m "feat: two-tier loadWeather (fetchWeather action + stub fallback)"`

---

## Task 4: `WeatherScreen`

**Files:** Create `Haven/Sources/Weather/WeatherScreen.swift`; delete `WeatherPlaceholder.swift`; modify `RootTabView.swift`.

- [ ] **Step 1: Write `WeatherScreen.swift`**
```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct WeatherScreen: View {
    @Environment(\.theme) private var theme
    let weather: Weather

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("Weather").havenText(.screenTitle, color: theme.ink)
                    RiskHero(weather: weather)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s4), GridItem(.flexible(), spacing: Spacing.s4)], spacing: Spacing.s4) {
                        cell(icon: "gauge", k: "Pressure swing", v: "\(weather.swing)", unit: "hPa", t: trendLabel, spark: weather.pressureTrend)
                        cell(icon: "thermometer", k: "Temp swing", v: "\(weather.tempSwing)", unit: "°", t: "Now \(weather.temp)°", spark: [])
                        cell(icon: "drop", k: "Humidity", v: "\(weather.humidity)", unit: "%", t: "Logged, not led on", spark: [])
                        cell(icon: "wind", k: "Wind", v: "—", unit: "mph", t: "Light", spark: [])
                    }
                    noteCard
                }.padding(Spacing.s6)
            }
        }
    }

    private var trendLabel: String { weather.trend == "falling" ? "Falling — strongest signal" : weather.trend.capitalized }

    private func cell(icon: String, k: String, v: String, unit: String, t: String, spark: [Double]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: Spacing.s2) { Image(systemName: icon).foregroundStyle(theme.inkSoft); Text(k).havenText(.eyebrow, color: theme.inkFaint) }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
                Text(v).havenText(.riskWord, color: theme.ink)
                Text(unit).havenText(.meta, color: theme.inkSoft)
            }
            Text(t).havenText(.meta, color: theme.inkSoft)
            if !spark.isEmpty { Sparkline(values: spark).frame(height: Spacing.s8) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s5).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: Spacing.s2) { Image(systemName: "cloud").foregroundStyle(theme.accent); Text("Why this matters").havenText(.sectionHead, color: theme.ink) }
            Text("Pressure and temperature are the strongest recurring weather signals in the research. When barometric pressure drops quickly, the change can set off attacks in sensitive people. Humidity is logged but not led on.")
                .havenText(.body, color: theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s5).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }
}

struct Sparkline: View {
    @Environment(\.theme) private var theme
    let values: [Double]
    var body: some View {
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        HStack(alignment: .bottom, spacing: Spacing.s1) {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                let frac = (hi - lo) == 0 ? 0.5 : (v - lo) / (hi - lo)
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(i >= values.count - 3 ? theme.risk : theme.track)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing.s2 + CGFloat(frac) * Spacing.s7)
            }
        }
    }
}
```

- [ ] **Step 2: Modify `RootTabView.swift`** — change `case .weather: WeatherPlaceholder()` → `case .weather: WeatherScreen(weather: store.weather)`. Delete `Haven/Sources/Weather/WeatherPlaceholder.swift`.
- [ ] **Step 3: Build → SUCCEEDED, guard → pass. Commit** — `git add Haven/Sources/Weather Haven/Sources/App/RootTabView.swift && git commit -m "feat: add WeatherScreen, replace placeholder"` (the `git add` of the deleted placeholder is captured by `git add Haven/Sources/Weather` staging the deletion).

---

## Task 5: Maestro + fidelity

**Files:** Create `Haven/maestro/weather.yaml`.

- [ ] **Step 1: Seed + build/install/launch** (current date).
- [ ] **Step 2: Write `weather.yaml`**
```yaml
appId: app.haven.Haven
---
- launchApp
- assertVisible: "Today"
- tapOn:
    point: "87%,95%"      # weather tab (4th slot)
- assertVisible: "Weather"
- assertVisible: "Pressure swing"
- assertVisible: "Why this matters"
- takeScreenshot: m4-weather
```
- [ ] **Step 3: Run** — `maestro test Haven/maestro/weather.yaml` → COMPLETED. Read `m4-weather.png`; confirm the risk hero + 4 cells + sparkline render. (Weather may be the stub or live depending on whether the Convex action reached Open-Meteo — either renders.)
- [ ] **Step 4: Fidelity** — compare to the prototype WeatherScreen; reconcile obvious gaps.
- [ ] **Step 5: Commit** — `git add Haven/maestro/weather.yaml && git commit -m "test: add M4 weather Maestro flow"`

---

## Definition of done
1. Weather tab shows the risk hero + pressure/temp/humidity/wind cells + a pressure sparkline.
2. `fetchWeather` deployed; `npx convex run weather:fetchWeather` returns real data; offline → stub (hero still renders).
3. Today's RiskHero reflects the loaded weather.
4. All suites green; guard clean; app builds; Maestro green; screen matches the prototype.

## Self-review notes
- **Spec coverage:** model extension §5 (T1), action §4 (T2), two-tier store + ConvexService §3/§5 (T3), WeatherScreen §6 (T4), Maestro/fidelity §7 (T5).
- **Build continuity:** T3 grows `DayDataSource` AND implements `ConvexService.fetchWeather` in the same task → app build never left broken across a commit boundary (unlike M2/M3, fixed here).
- **Type consistency:** `Weather` Codable shape matches the action's return JSON exactly (level low/mid/high, swing, pressureTrend). `client.action(...)` decodes into `Weather` like `analyzeFood`→`AnalyzedFood`. `loadWeather` mirrors the food `analyze` two-tier pattern.
- **Risks:** Open-Meteo reachability from Convex's Node runtime (verified via `npx convex run`); the live response isn't unit-tested; wind is a placeholder "—" (Open-Meteo provides `wind_speed_10m` but the cell shows "—" for M4 simplicity — a follow-up can surface it).
