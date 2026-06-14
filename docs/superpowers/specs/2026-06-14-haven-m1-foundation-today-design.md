# Haven — Milestone 1: Foundation + Today (Design Spec)

**Date:** 2026-06-14
**Status:** Approved for planning
**Milestone:** 1 of 5 (see [README roadmap](../../../README.md))

---

## 1. Goal

A thin **end-to-end vertical slice** that de-risks every layer of the Haven stack at once:
a native SwiftUI app whose **Today** screen renders from **live, reactive Convex data**, with
**every visual value resolved through a ported design-system layer** — no color, font, spacing, or
radius literal anywhere in feature code.

Success = on a simulator, the Today screen shows seeded daily-log data through fully tokenized UI;
editing a daily factor writes to Convex and the UI updates reactively; flipping dark↔light re-themes
the entire screen from a single switch.

### Non-goals (deferred to later milestones)
Calendar / Insights / Weather tabs · real barometric weather API · food capture + AI analysis ·
onboarding / paywall / StoreKit · real account auth UI · the full bottom-sheet set.

---

## 2. Confirmed decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Client | Native iOS / SwiftUI, **iOS 17+** |
| 2 | Backend | **Convex** (reactive DB, actions, storage, auth, crons) |
| 3 | One write path in M1 | **Yes** — a minimal factor editor proves mutations round-trip (not read-only) |
| 4 | Auth in M1 | **Anonymous / device identity** (no login UI); real accounts in M5 |
| 5 | px → pt | **Treat token px as points** (faithful to the 372pt design frame); fonts scale under Dynamic Type, spacing/radii fixed |
| 6 | Weather in M1 | **Stubbed** local mock matching the real shape; `fetchWeather` action is M4 |
| 7 | Tooling | **XcodeGen** (`project.yml`) + `convex` CLI — terminal-reproducible |
| 8 | "Logged today" list | A **ledger** of *all* log types (food, migraine, symptoms, factors), not food-only; derived + time-sorted (see §6.5). Weather is excluded — it's never logged. |

---

## 3. Architecture overview

```
┌─────────────────────────────── iOS app (SwiftUI) ───────────────────────────────┐
│                                                                                  │
│  Feature targets (App/, Onboarding/, …)                                          │
│     │  consume ONLY public design-system + service APIs                          │
│     ▼                                                                            │
│  HavenDesignSystem (Swift module)        HavenServices                           │
│   • Primitives (internal)                 • ConvexService  ──reactive sub──┐      │
│   • Global tokens (public)                • Models (Codable)               │      │
│   • Theme + ThemeController (public)      • WeatherStub                    │      │
│   • Typography / TextStyle                                                 │      │
└────────────────────────────────────────────────────────────────────────────┼────┘
                                                                              │
                                          Convex deployment ◄────────────────┘
                                           • schema: days, settings, foods
                                           • queries: getDay, getSettings
                                           • mutations: setFactors, updateSettings, seed
                                           • anonymous auth identity
```

**Module boundary is the enforcement mechanism.** Primitives are `internal` to
`HavenDesignSystem`, so feature code physically cannot reference a raw hex or magic number — it can
only reach the `public` semantic tokens. This makes "everything connects to the design system" a
compile-time guarantee, not a code-review hope.

---

## 4. Design system — `HavenDesignSystem`

Ports `design_handoff/prototypes/haven-tokens.css` faithfully. Three layers, mirroring the file.

### 4.1 Layer 1 — Primitives (`internal`)
The only place raw values live. Names mirror the `--p-*` tokens.

```swift
enum Primitives {                       // internal to the module
    // Brand · orange
    static let orange600 = Color(hex: 0xec6a1e)
    static let orange500 = Color(hex: 0xef6a20)
    static let orange300 = Color(hex: 0xe89766)
    static let orangeInk = Color(hex: 0x1c0f06)
    // Warm charcoal, cream/sand, paper, semantic hues (sage/amber/clay) …
    // (full 1:1 port of the --p-* block)
}
```

### 4.2 Layer 2 — Global tokens (`public`, theme-agnostic)
Exact px values from the file, expressed as points.

```swift
public enum Spacing { public static let s1: CGFloat = 4, s2 = 6, s3 = 9, s4 = 11,
                                          s5 = 14, s6 = 16, s7 = 20, s8 = 22, s10 = 30 }
public enum Radius  { public static let xs: CGFloat = 8, sm = 13, md = 14, lg = 18,
                                          xl = 20, xxl = 26, pill = 999 }
// (screen/device radii are phone-frame chrome — omitted)
```

### 4.3 Layer 3 — `Theme` (`public`, varies dark/light)
A struct of semantic color tokens; two static instances. 1:1 with `.theme-dark` / `.theme-light`.

```swift
public struct Theme {
    public let bg, surface, chip, ink, inkSoft, inkFaint, hairline, track: Color
    public let accent: Color, streakBg: Color
    public let risk, riskBg, riskInk: Color
    public let ctaBg, ctaInk: Color
    public let ctaShadow: ShadowToken
    public let tabbarBg, tabActiveBg, tabActiveInk: Color
    public let factorGood, factorMid, factorHigh: Color

    public static let dark: Theme  = …   // maps Primitives per .theme-dark
    public static let light: Theme = …   // maps Primitives per .theme-light
}
```

Factor/severity mapping helper: `high → factorHigh (clay)`, `medium → factorMid (amber)`,
`low → factorGood (sage)`.

### 4.4 Typography (token-driven)
A `TextStyle` value captures family + size + weight + leading + tracking; named styles cover the
prototype's usage. One modifier applies font + kerning + line-spacing + a semantic color.

```swift
public struct TextStyle { let family: FontFamily; let size, weight: CGFloat
                          let leading, tracking: CGFloat }       // tracking in em
public extension TextStyle {
    static let screenTitle  = …   // serif 34, leading 1.06, tracking -0.015em
    static let riskWord     = …   // serif 31 (display)
    static let sectionHead  = …   // sans 15 / 600
    static let body         = …   // sans 13.5
    static let meta         = …   // sans 12.5
    static let columnLabel  = …   // sans 19
    static let eyebrow      = …   // sans, tracking +0.14em, uppercased
}
// Usage: Text("Today").havenText(.screenTitle, color: theme.ink)
```

- **Fonts:** Source Serif 4 (variable, optical sizing) + Hanken Grotesk bundled in
  `Resources/Fonts/` and registered via `UIAppFonts`.
- **Kerning** = `tracking_em * size` (points). **Line-spacing** ≈ `size * (leading − 1)`.
- **Dynamic Type:** font sizes scale via `UIFontMetrics`; spacing/radii stay fixed.

### 4.5 ThemeController (configurability)
```swift
@Observable public final class ThemeController {
    public var mode: ThemeMode = .dark            // dark default; persisted (UserDefaults → later settings)
    public var theme: Theme { mode == .light ? .light : .dark }
}
```
Injected at the root via `.environment(\.theme, controller.theme)`. Runtime switch re-themes
everything because all views read `@Environment(\.theme)`.

### 4.6 Enforcement
1. **Compile-time:** Primitives are `internal`; feature targets depend only on the module's `public` API.
2. **Guard script:** a pre-commit / CI grep fails on `Color(`, `UIColor(`, `.font(.system`, or bare
   numeric literals in feature targets (allow-list the design-system module itself).

### 4.7 Icons
Map the prototype's outline set to **SF Symbols** where a faithful light/rounded match exists;
bundle custom SVG-derived assets otherwise. Icon style (stroke weight, rounding) is itself sourced
from tokens where applicable. Full name list: `design_handoff/prototypes/app/icons.jsx`.

---

## 5. Backend — Convex (minimal for M1)

### 5.1 Schema (`convex/schema.ts`)
```ts
days: defineTable({
  userId: v.string(),
  date: v.string(),                              // "YYYY-MM-DD"
  factors: v.optional(v.object({ sleep: v.number(), stress: v.string(),
                      hydration: v.string(), weatherSensitive: v.boolean() })),
  factorsLoggedAt: v.optional(v.string()),       // ledger timestamp for the factors entry
  migraine: v.optional(v.object({ had: v.boolean(), severity: v.string(),
                                  time: v.string(), notes: v.string() })),
  symptoms: v.array(v.string()),
  symptomsLoggedAt: v.optional(v.string()),      // ledger timestamp for the symptoms entry
}).index("by_user_date", ["userId", "date"]),

settings: defineTable({ userId: v.string(), theme: v.string() })
            .index("by_user", ["userId"]),

foods: defineTable({ /* defined for schema completeness; capture is M2 */ })
```

### 5.2 Functions
| Kind | Name | Purpose |
|---|---|---|
| query | `getDay(date)` | Reactive read of the day's log for the current identity. |
| query | `getSettings()` | Theme + settings. |
| mutation | `setFactors(date, factors)` | **The M1 write path.** Upsert the day's factors. |
| mutation | `updateSettings(patch)` | Persist theme choice. |
| mutation | `seed()` | Load realistic demo days so Today looks alive (fixtures, dev only). |

### 5.3 Auth
Convex **anonymous identity** — every install gets a stable device identity so reads/writes are
scoped and the sync path is genuinely exercised. No login UI. Real accounts → M5.

### 5.4 Weather stub
`WeatherStub` (client-side) returns a deterministic
`{ level, bars, swing, tempSwing, humidity, temp, trend, headline, detail }` matching the real
contract, so the risk hero is real UI on fake data. Swapped for the `fetchWeather` action in M4.

---

## 6. Client — Today screen

### 6.1 Data flow
`ConvexService` (wrapping `convex-swift` via SPM) opens a reactive subscription to `getDay(today)`;
results decode into `Codable` models and publish through an `@Observable TodayStore`; SwiftUI views
observe it. A `setFactors` call from the UI mutates Convex → the subscription pushes the update back
→ the ring re-renders. No manual refresh.

### 6.2 Models
`DayLog`, `Factors`, `Migraine`, `Settings`, `Weather` — `Codable`, decoded from Convex documents.

### 6.3 View composition (all tokenized)
- **StatusBar** — defer to the real iOS status bar (the prototype's fake 9:41 bar is chrome).
- **TopBar** — serif title "Today" + date (`.screenTitle` / `.meta`), streak flame chip
  (`streakBg`/`accent`), search + profile icon buttons.
- **RiskHero** — `risk*` tokens, `radius.xxl` card: eyebrow label, big serif risk word
  (`.riskWord`), a 4-bar gauge, headline + detail. Tappable (no-op in M1; routes to Weather in M4).
- **FactorRings** — three rings Sleep / Stress / Water, colored via the factor→token map; each
  `radius.xl` card. **Tap → minimal factor editor** (sleep stepper, stress/hydration segmented) →
  `setFactors` → reactive update. (Polished Daily-factors sheet is M2.)
- **Action buttons** — "Log a migraine" (cta primary) + "Snap a meal" (ghost) rendered to spec;
  wired in M2.
- **Migraine alert card** — conditional ("current status" callout); reads `day.migraine`.
- **Summary card** — conditional; symptom chips + factors text ("current status" callout).
- **"Logged today" — the day ledger.** A single chronological list of *every* entry the user
  logged that day, not just food (see §6.5). In M1 this renders seeded food/migraine/symptoms plus
  the factors the user edits; food *capture* is still M2, but food *entries* already appear here.

### 6.5 The day ledger ("Logged today")

A **ledger** is the running record of the day: every discrete log is an entry, shown newest-/oldest-
first by timestamp. It is *derived at render time* by merging the day document's sub-records into one
sorted list — there is no separate "events" table.

| Entry type | Source | Timestamp | Row |
|---|---|---|---|
| Food | each `day.foods[]` | `food.time` | existing `FoodCard` (thumb, name, trigger chips) |
| Migraine | `day.migraine` (if `had`) | `migraine.time` | severity · time · notes, alert-styled |
| Symptoms | `day.symptoms` (if non-empty) | `day.symptomsLoggedAt` | the logged symptom chips |
| Factors | `day.factors` (if set) | `day.factorsLoggedAt` | "Sleep 6.5h · Stress high · Water low…" |

Rules:
- **Weather never appears** — it is external context (the risk hero), never user-logged.
- Factors/symptoms appear in the ledger **and** as their "current status" surfaces (rings / summary
  / migraine alert). That redundancy is intentional: the ledger is the *record*, the top-of-screen
  cards are the *current state*.
- Empty state when the ledger has zero entries.
- Each entry type is a small, independently testable row view; the ledger is `[LedgerEntry]` built
  by a pure mapping function over `DayLog`.

### 6.4 Streak
Derived client-side from the seeded day range: consecutive days ending today with any entry.

---

## 7. Tooling & project setup (terminal-reproducible)

- **`project.yml`** (XcodeGen) defines the app target, the `HavenDesignSystem` module, test targets,
  bundled fonts, and SPM dependencies (`convex-swift`). `xcodegen generate` rebuilds the `.xcodeproj`
  from source — nothing hand-edited in Xcode is load-bearing.
- **`convex/`** + `package.json`; `npx convex dev` provisions the deployment and watches functions.
- **Secrets:** none required for M1 (weather stubbed, no LLM yet).

---

## 8. Testing strategy

| Layer | Test |
|---|---|
| Design system | `Theme.dark`/`.light` resolve every semantic token; factor→color map correct; `TextStyle` kerning/line-spacing math. |
| Models | Convex document JSON → `Codable` decode round-trips. |
| Convex | Smoke tests for `getDay` / `setFactors` upsert semantics (function tests). |
| Enforcement | Guard script flags a deliberately-hardcoded color in a feature target. |
| UI (light) | Today renders seeded data; factor edit triggers a `setFactors` call (snapshot optional). |

---

## 9. Definition of done

1. `xcodegen generate` + `npx convex dev` bring the app up from a clean checkout via terminal only.
2. Today renders seeded Convex data; all visuals come from tokens (guard script passes).
3. Editing a factor writes to Convex and the ring updates reactively.
4. Dark↔light switch re-themes the whole screen from one control.
5. Tests in §8 pass.

---

## 10. Open risks

- **`convex-swift` maturity** — reactive subscription ergonomics in SwiftUI are the biggest unknown;
  the M1 slice exists partly to surface this early. Fallback: a thin polling/one-shot adapter if
  live subscriptions prove rough.
- **Font fidelity** — Source Serif 4 optical sizing + Hanken Grotesk metrics vs the web prototype;
  verify the title/risk-word rendering against the prototype screenshots.
