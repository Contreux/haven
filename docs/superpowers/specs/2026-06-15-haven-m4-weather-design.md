# Haven — Milestone 4: Weather (Design Spec)

**Date:** 2026-06-15
**Status:** Approved for planning (standing authorization)
**Milestone:** 4 of 5

---

## 1. Goal

Replace the deterministic `WeatherStub` with **real barometric-pressure risk**, and build the full **Weather** screen. Pressure + temperature swings are the strongest recurring weather migraine signals, so Today's risk hero and the Weather tab should reflect actual forecast data — degrading gracefully to the stub when offline.

### Non-goals
Device location via CoreLocation + permission UX (deferred to M5 onboarding — M4 uses a default location) · onboarding/paywall (M5).

---

## 2. Confirmed decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Weather API | **Open-Meteo** (`api.open-meteo.com`) — free, **no API key**, no dashboard. Fits terminal-only. |
| 2 | Fields | hourly `surface_pressure`, `temperature_2m`, `relative_humidity_2m`, `wind_speed_10m`. |
| 3 | Risk model | pressure **swing** over the next ~8h: ≥8 hPa → high (Elevated), ≥4 → mid (Moderate), else low (Calm). Matches the prototype's `mockWeather` thresholds. |
| 4 | Resilience | **Two-tier**: `fetchWeather` action is the source; `WeatherStub` is the offline fallback (store catches any error → stub). |
| 5 | Location | **Default lat/lon constant** for M4 (e.g. London 51.51, -0.13). Real device/onboarding location is M5. `fetchWeather` takes `lat`/`lon` args. |
| 6 | Model | Extend `Weather`: add `swing: Int` (hPa) + `pressureTrend: [Double]`; make `Weather` `Codable` so the action result decodes directly. |

---

## 3. Architecture

```
TodayStore.loadWeather():
  try fetchWeather(lat, lon) action  ─ Open-Meteo ─► compute swing/level/bars/trend ─► Weather
  catch → WeatherStub.weather(for: today)            (offline fallback)
        │
        ▼
   store.weather (Weather)  ──► Today RiskHero + WeatherScreen (4-cell grid)
```

`fetchWeather` is a Convex action (Node runtime, `fetch`). The risk computation (swing → level/bars/headline) is shared logic — implemented in the action (TS) and mirrored by the existing stub (Swift). The Swift `Weather` model decodes the action's JSON.

---

## 4. Backend — `fetchWeather` action

`convex/weather.ts` (`"use node"`):
```ts
fetchWeather({ lat, lon }) -> {
  level: "low"|"mid"|"high", bars: number, swing: number, tempSwing: number,
  humidity: number, temp: number, trend: "rising"|"falling"|"steady",
  headline: string, detail: string, pressureTrend: number[]
}
```
Calls `https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=surface_pressure,temperature_2m,relative_humidity_2m,wind_speed_10m&forecast_days=1`. From the hourly arrays:
- `pressureTrend` = the next 8 `surface_pressure` readings.
- `swing` = round(max − min of those 8) (hPa).
- `tempSwing` = round(max − min of the next 8 `temperature_2m`); `temp` = current; `humidity` = current.
- `trend` = "falling" if pressure decreasing over the window, "rising" if increasing, else "steady".
- `level`/`bars`/`headline`/`detail` per the thresholds (≥8 high/3 bars/"Pressure dropping {swing} hPa"; ≥4 mid/2 bars/"Shifting front"; else low/1 bar/"Calm pressure"), with `detail` mentioning the temp swing.

No API key, no env var. The action throws on network/parse failure → client falls back to the stub. Tested by shape (mock fetch) or by the throws path; the live call is integration-only.

---

## 5. HavenCore — model

Extend `Weather` (`Weather.swift`): add `public let swing: Int` and `public let pressureTrend: [Double]`; conform to `Codable` (so it decodes the action result). Update `WeatherStub.weather(for:)` to populate the two new fields (swing derived from the seed; a short synthetic `pressureTrend`). Existing tests updated; add a decode test for the action-shaped JSON.

`DayDataSource` gains `func fetchWeather(lat: Double, lon: Double) async throws -> Weather`. `TodayStore` gains `loadWeather()` (two-tier) called from `start()`, and `weather` becomes a `private(set) var` updated by it (currently a `let` from the stub). Default location constant in the store or service.

---

## 6. Client — WeatherScreen

Replaces `WeatherPlaceholder`. Per the prototype `WeatherScreen`:
- Title "Weather" + the shared **RiskHero** (reused).
- **4-cell grid** (`wx-grid`): Pressure swing ("{swing} hPa", trend label, a **sparkline** from `pressureTrend`); Temp swing ("{tempSwing}°", "Now {temp}°"); Humidity ("{humidity}%"); Wind ("{wind} mph"). Each cell tokenized card with an icon, big value, caption.
- **Sparkline** = a small `Path`/bar row from `pressureTrend` (normalized heights), last few highlighted.
- "Why this matters" note card (pressure/temperature are the strongest signals; humidity logged not led on).

Wire `RootTabView`'s `.weather` tab to `WeatherScreen(weather: store.weather)`, and Today's `RiskHero(weather: store.weather)` already reads the store — now backed by the real fetch.

---

## 7. Testing strategy

| Layer | Test |
|---|---|
| Convex | `fetchWeather` shape/throws (mock fetch or the error path). |
| HavenCore | `Weather` Codable decode of the action JSON (swing/pressureTrend); `WeatherStub` still deterministic with the new fields; `TodayStore.loadWeather` two-tier (action success vs fallback) via fake. |
| UI (Maestro) | open Weather tab → see the risk hero + the 4 cells; values render. |
| Fidelity | WeatherScreen screenshot vs the prototype. |

---

## 8. Definition of done
1. Today's RiskHero + the Weather tab show real Open-Meteo-derived risk for the default location; offline → stub (no crash, hero still renders).
2. WeatherScreen shows the risk hero + pressure/temp/humidity/wind cells with a pressure sparkline.
3. All suites pass; guard clean; app builds; Maestro green; screen matches the prototype.

---

## 9. Open risks
- **Open-Meteo availability/shape** — defensive parse; throw → stub fallback (tested). The live response isn't unit-tested (network).
- **Convex action network egress** — actions run in Convex's cloud (Node), which can reach Open-Meteo; verify the deployed action returns data via `npx convex run`.
- **Two-tier timing** — `loadWeather()` runs async at start; the hero shows the stub until the real value arrives (acceptable; it updates reactively).
- **Default location** is a placeholder; M5 onboarding sets the real one.
