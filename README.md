# Haven — Migraine Tracking App

**Haven** helps people with migraines find what triggers them. Users log meals (with
AI-assisted dietary-trigger analysis), daily factors (sleep / stress / hydration), symptoms,
and migraine attacks. Haven correlates these against a **barometric-weather risk** signal and
surfaces a ranked, plain-language picture of what most likely sets a person's attacks off.

The product is **calm, warm, and clinical** — never alarmist. Triggers are framed as
*hypotheses to explore*, not verdicts.

---

## Status

Greenfield rebuild. The original prototype was an HTML/CSS/React-via-Babel design reference
(now preserved under [`design_handoff/`](./design_handoff)). This repository rebuilds Haven as a
**native iOS app with a Convex backend**.

The design handoff is **high-fidelity and final**: colors, typography, spacing, radii, copy, and
interactions are intentional. `design_handoff/prototypes/haven-tokens.css` is the **single source
of truth** for the design system and should be ported faithfully, not eyeballed.

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| **Client** | Native **iOS / SwiftUI** (iOS 17+) | Mobile-first product; native feel for sheets, gestures, status bar, permissions. |
| **Backend** | **Convex** | Reactive DB with automatic cross-device sync; TypeScript actions for AI/weather proxies; built-in file storage, auth, and crons. |
| **AI** | LLM via a Convex `action` | Keeps the API key server-side. On-device keyword fallback guarantees offline analysis. |
| **Weather** | Barometric API proxied through Convex | Location → pressure/temp/humidity/wind → risk signal. |
| **Subscriptions** | StoreKit 2 + server-side receipt validation (Convex action) | App Store entitlements verified off-device. |
| **Fonts** | Source Serif 4 (display) + Hanken Grotesk (UI) | Bundled. |
| **Setup** | **Terminal / CLI only** | `convex` CLI + Xcode toolchain. No web-dashboard steps required. |

### Why Convex

- **Sync is the default, not an add-on.** The reactive document DB pushes changes to subscribed
  clients automatically, so "the daily log syncs across devices" comes essentially for free.
- **Actions are the right home for the AI + weather calls.** Server-side TypeScript keeps secrets
  off-device; queries/mutations handle the logs.
- **Batteries included:** file storage (food photos), auth, and scheduled functions (the daily
  reminder nudge, weather refresh) are all first-party.
- **CLI-first:** `npx convex dev` provisions a deployment and pushes functions; `npx convex deploy`
  ships. Matches the terminal-only constraint.

**Known tradeoff:** the Convex Swift client (`convex-swift` / ConvexMobile) is younger than its
React counterpart. It supports reactive queries, mutations, and actions — which is what Haven
needs — but expect a thinner ecosystem than a more mature mobile SDK.

---

## Product Surfaces

### 1. Onboarding + Paywall

A linear, back-navigable flow:

1. **Welcome** — flame mark, serif headline, "Get started" CTA, "I already have an account" skip.
2. **11-question intake quiz** — progress bar + step counter, kicker, serif title, options, sticky
   "Continue" (disabled until answered). Two option layouts: full-width **list** rows and 2-column
   **grid** chips (multi-select symptoms & triggers). Questions: `frequency`, `duration`, `age`,
   `sex`, `cycle` *(conditional — only if sex ∈ female/intersex)*, `aura`, `symptoms` (multi),
   `severity`, `triggers` (multi + "not sure"), `meds`, `goal` (multi).
3. **Synthesis** — a ~2.5s "Building your profile" loader, then a reveal card deriving a **profile
   class** (Episodic/Chronic [with aura]), suspected-trigger chips, and a "what Haven will watch
   for you" checklist — all computed from the answers.
4. **Weather permission primer** → fires the real OS location prompt.
5. **Reminders permission primer** — 2×2 time-of-day picker (Morning / Midday / Evening / Before bed).
6. **Paywall** — feature list + two plans: **Yearly** ($83.20/yr → $1.60/wk, "SAVE 87% · 7 DAYS
   FREE", default) and **Weekly** ($12/wk). CTA switches: "Start 7-day free trial" vs "Subscribe
   weekly". Closeable (skips to done).
7. **Done** — "You're all set", copy varies if a trial started, "Enter Haven".

### 2. Main App — four tabs + center speed-dial

- **Today** — top bar (date + streak flame); tappable **weather-risk hero** (big serif risk word +
  4-bar gauge + headline/detail); **three factor rings** (Sleep / Stress / Water, color-coded
  good/mid/high); "Log a migraine" + "Snap a meal" actions; optional "migraine today" danger card;
  symptom/factors summary; then the **"Logged today" ledger** — a single chronological record of
  *every* entry logged that day (food, migraine, symptoms, factors), or an empty state. Weather is
  excluded; it's external context, never user-logged. The rings/cards above show *current state*,
  the ledger shows the running *record*.
- **Calendar** — month grid; each day shows a severity-colored ring (migraine), a dot (food), or a
  small dot (symptoms only). Tap a day → **Day Detail** sheet.
- **Insights** — three big stats; a **ranked trigger list** (rank, name, "N migraines"/"no overlap"
  tag, level-colored share bar, "eaten N times"), ranked by overlap-with-migraine-days then
  frequency; closes with a calm "A note on patterns" card.
- **Weather** — the risk hero, a 2×2 metric grid (Pressure swing + sparkline, Temp swing, Humidity,
  Wind), and a "why this matters" explainer. Pressure & temperature are the strongest signals.

**Bottom sheets** (scrim + rounded-top sheet + grab handle):
- **Log a migraine** — Mild/Moderate/Severe segmented control, notes, Save; Remove if one exists.
- **Log symptoms** — 2-col multi-select grid.
- **Daily factors** — Sleep slider (0–12h, 0.5 step), Stress & Hydration segmented (Low/Med/High),
  "weather-sensitive today" toggle, Save.
- **Log food (capture)** — full-screen **dark** overlay. Two modes: **Photo** (camera/library) and
  **Describe** (text). "Analyze" runs the trigger engine (with a brief "thinking" beat), then shows
  per-trigger rows (dot + level + reason) → "Save to today" / "Redo".

---

## Design System (port this first)

`design_handoff/prototypes/haven-tokens.css` has three layers. **Replicate this indirection in
SwiftUI so dark/light theming stays a one-file change.**

1. **Primitives** (`--p-*`) — the only place raw hex lives (warm charcoals, creams/sands, the orange
   spark, semantic hues for factor rings).
2. **Global tokens** — radii, spacing, typography, elevation. Theme-agnostic.
3. **Themes** — `.theme-dark` (default) and `.theme-light` map primitives onto **semantic tokens**.
   **Views consume only semantic tokens, never raw hex.**

### Key semantic tokens

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#1c1712` | `#f1ece4` | App background |
| `surface` | `#272019` | `#e7e0d6` | Cards / chips / sheets |
| `ink` | `#f3ece3` | `#1d1813` | Primary text |
| `ink-soft` | `#a99c8c` | `#8c8073` | Secondary text |
| `ink-faint` | `#74695c` | `#b0a597` | Tertiary / meta |
| `hairline` | `#2c241c` | `#e3dccf` | Dividers / borders |
| `accent` | `#ef6a20` | `#ec6a1e` | Spark / streak / links |
| `cta` | orange `#ef6a20` on `#1c0f06` | ink `#34302a` on `#f4ede4` | Primary button |
| `risk` | amber `#d79a4e` | amber `#c2873a` | Weather-risk hero |
| `factor good / mid / high` | sage `#8a9966` / amber `#d79a4e` / clay `#cf7551` | `#7f8a5d` / `#c2873a` / `#bd6446` | Rings, trigger dots, severity |

**Trigger levels map to factor colors: high → clay/red, medium → amber, low → sage/green.**

### Type & scale

- **Serif (display):** Source Serif 4 — screen titles, the risk word, profile class.
- **Sans (UI/body):** Hanken Grotesk — everything else. Weights 400/500/600/700.
- Scale (px, tuned to the 372×806 design frame — convert proportionally to a Dynamic Type scale):
  `xs 11`, `sm 12.5`, `base 13.5`, `md 15`, `lg 19`, `title 34` (serif), `display 31` (serif).
- **Spacing (px):** `1:4 2:6 3:9 4:11 5:14 6:16 7:20 8:22 10:30`.
- **Radii (px):** `xs 8`, `sm 13`, `md 14`, `lg 18`, `xl 20`, `2xl 26`, `pill 999`.
- **Elevation:** soft, warm shadows; mostly flat with hairline borders doing the separation. CTA
  glow (dark): `0 8px 26px -10px rgba(239,106,32,.6)`.

### Brand tone

Warm, calm, clinical. Orange is a **spark used sparingly** (accent/CTA only) on a warm charcoal
(dark) or warm paper (light) ground. **No cold grays** — every neutral is warm-toned.

### Icons

A single light, rounded, outline set (24×24, ~1.7–1.8px stroke). Map to SF Symbols where a faithful
match exists; bundle custom assets otherwise. Full reference list in
`design_handoff/prototypes/app/icons.jsx`.

---

## Data Model

Daily log keyed by `YYYY-MM-DD`:

```jsonc
{
  "date": "2026-06-14",
  "foods": [
    { "id": "...", "label": "Aged cheddar toastie", "time": "12:30", "note": "",
      "thumb": "<storageId>",
      "triggers": [ { "name": "Aged cheese", "level": "high", "reason": "tyramine" } ] }
  ],
  "migraine":  { "had": true, "severity": "moderate", "time": "15:10", "notes": "" },
  "symptoms":  ["light", "nausea"],
  "symptomsLoggedAt": "14:40",
  "factors":   { "sleep": 6.5, "stress": "high", "hydration": "low", "weatherSensitive": true },
  "factorsLoggedAt": "09:02"
}
```

Each sub-record carries a timestamp (`food.time`, `migraine.time`, `symptomsLoggedAt`,
`factorsLoggedAt`) so the Today **ledger** can merge them into one chronological list.

Plus:
- **Onboarding profile** — the quiz answers and derived profile class / watch-list.
- **Settings** — theme, reminder time, subscription / plan / trial state.
- **Weather** (per location/day): `{ level, bars, swing, tempSwing, humidity, temp, trend[], headline, detail }`.

---

## Backend (Convex) — functions

| Kind | Name | Responsibility |
|---|---|---|
| `query` | `getDay`, `getRange`, `getProfile`, `getSettings` | Reactive reads for Today/Calendar/Insights. |
| `mutation` | `upsertFood`, `deleteFood`, `setMigraine`, `setSymptoms`, `setFactors`, `saveProfile`, `updateSettings` | Writes to the daily log / profile / settings. |
| `action` | `analyzeFood` | LLM call with the trigger-analysis prompt; returns `{ label, triggers[], note }`. **Falls back to the on-device engine on any failure.** |
| `action` | `fetchWeather` | Calls the barometric API, computes the risk signal, caches per location/day. |
| `action` | `validateSubscription` | Verifies the StoreKit receipt with Apple, writes entitlement. |
| `storage` | — | Food photos (downscaled ~180px thumbnails). |
| `cron` | `dailyReminder`, `refreshWeather` | The gentle daily nudge + weather refresh. |

### Food-trigger analysis (two-tier, keep both)

1. **Primary:** `analyzeFood` action asks the LLM for minified JSON —
   `{ label, triggers:[{name, level, reason}], note }`, `level ∈ high|medium|low`.
2. **Fallback:** an **on-device** Swift port of the prototype's keyword/regex engine
   (aged cheese→tyramine, cured meat→nitrates, alcohol, MSG, chocolate, caffeine, sweeteners,
   citrus, fermented/yeast, nuts, tomato, soy sauce). Triggers sorted high→low.

Analysis **must work without a network round-trip** — always show a brief "Analyzing" beat, then
results, falling back silently when offline or the call fails.

---

## Repository Layout

```
Migraine/
├── Haven/                  # SwiftUI app (Xcode project)
│   ├── Theme/              # ported design tokens (primitives → semantic → dark/light)
│   ├── Onboarding/         # welcome → quiz → synthesis → primers → paywall → done
│   ├── App/                # Today / Calendar / Insights / Weather + bottom sheets + capture
│   ├── Services/           # Convex client, on-device food fallback engine, StoreKit
│   └── Resources/          # fonts, icons
├── convex/                 # schema, queries, mutations, actions, crons
├── design_handoff/         # the original prototype — design source of truth (reference only)
└── README.md
```

---

## Getting Started (terminal-only)

> Prerequisites: Xcode 16+ (iOS 17 SDK), Node 18+, and `npm`. No web dashboards required.

```bash
# 1. Backend — provision a Convex dev deployment and start the function watcher
npm install
npx convex dev            # logs in via token, creates the deployment, pushes functions

# 2. Configure server-side secrets (kept off-device)
npx convex env set LLM_API_KEY      "…"
npx convex env set WEATHER_API_KEY  "…"

# 3. Client — open and run the iOS app
xed Haven                 # opens the Xcode project; ⌘R to run on a simulator
```

The app reads its Convex deployment URL from the generated config; `npx convex dev` keeps functions
in sync as you edit. Ship the backend with `npx convex deploy`.

---

## Roadmap

1. **Design system** — port `haven-tokens.css` into the SwiftUI `Theme/` layer (dark default + light).
2. **Convex schema + core CRUD** — daily log, profile, settings, with reactive queries.
3. **Main app shell** — tabs, Today screen, factor rings, weather-risk hero.
4. **Loggers** — migraine / symptoms / daily-factors sheets + food capture.
5. **Food analysis** — on-device fallback engine first, then the `analyzeFood` action.
6. **Onboarding + paywall** — quiz, synthesis, primers, StoreKit plans.
7. **Calendar + Insights** — markers, ranked triggers.
8. **Weather** — `fetchWeather` action + the Weather tab.
9. **Crons** — daily reminder, weather refresh.

---

## Reference

The complete design intent — screen-by-screen behavior, copy, token values, and the food-analysis
prompt — lives in [`design_handoff/README.md`](./design_handoff/README.md) and the prototype source
under `design_handoff/prototypes/`. When in doubt about look, copy, or interaction, **that prototype
is the source of truth.**
