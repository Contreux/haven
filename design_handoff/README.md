# Handoff: Haven — Migraine Tracking App

## Overview
**Haven** is a mobile app that helps people with migraines find their triggers. Users log meals
(with AI-assisted dietary-trigger analysis), daily factors (sleep / stress / hydration), symptoms,
and migraine attacks. The app correlates these against a **barometric-weather risk** signal and surfaces
a ranked, plain-language picture of what most likely sets a person's attacks off.

Two product surfaces are included in this handoff:

1. **Onboarding + paywall flow** — an 11-question intake quiz, an AI-style "building your profile"
   synthesis screen, two permission primers (weather/location, daily reminder), a subscription paywall,
   and a completion screen.
2. **The main app** — four tabbed screens (Today, Calendar, Insights, Weather) plus a set of bottom-sheet
   loggers (migraine, symptoms, daily factors) and a full-screen "Log food" capture flow.

---

## About the Design Files
The files in `prototypes/` are **design references built in HTML/CSS/React-via-Babel** — they show the
intended look, layout, copy, and interaction behavior. **They are not production code to ship as-is.**
The Babel-in-the-browser setup, the `Object.assign(window, …)` cross-file sharing, and the localStorage
data layer are prototype scaffolding, not architectural recommendations.

**Your task:** recreate these designs in the target codebase using its established environment and patterns
(React Native, Swift/SwiftUI, Flutter, Kotlin, etc.). If no codebase exists yet, choose the most appropriate
stack for a mobile-first product and implement the designs there. **Treat the CSS token file as the real
deliverable** — it is a clean, framework-agnostic design system you should port faithfully into the target
platform's theming layer.

## Fidelity
**High-fidelity.** Colors, typography, spacing, radii, and interactions are all final and intentional.
Recreate the UI to match. Exact values live in `prototypes/haven-tokens.css` (the single source of truth) —
port those tokens rather than eyeballing the screenshots.

---

## How to run the prototypes
Open `prototypes/Haven Onboarding.html` or `prototypes/Haven App.html` in a browser. They use CDN React 18 +
Babel-standalone and external CSS/JSX files, so serve the `prototypes/` folder over a local static server
(file:// may block the module loads). The onboarding flow's "Enter Haven" button navigates to `Haven App.html`.
Both seed themselves with realistic demo data and persist to `localStorage`.

---

## Design System (port this first)

### Architecture
`haven-tokens.css` is the **single source of truth**. It has three layers:
1. **Primitives** (`--p-*`) — the only place raw hex values live (orange, warm charcoals, creams/sands, warm
   papers, semantic hues for the factor rings).
2. **Global tokens** — radii, spacing, typography, elevation. Theme-agnostic.
3. **Themes** — `.theme-dark` (default) and `.theme-light` map primitives onto **semantic tokens**
   (`--color-bg`, `--color-ink`, `--color-accent`, etc). **Components only ever consume semantic tokens, never
   raw hex.** Replicate this indirection in the target platform so dark/light theming stays a one-file change.

### Brand & tone
Warm, calm, clinical. Orange is a **spark used sparingly** (accent/CTA only), on a warm charcoal (dark) or
warm paper (light) ground. Avoid cold grays — every neutral is warm-toned.

### Color — key semantic tokens
| Token | Dark theme | Light theme | Use |
|---|---|---|---|
| `--color-bg` | `#1c1712` | `#f1ece4` | App background |
| `--color-surface` | `#272019` | `#e7e0d6` | Cards / chips / sheets |
| `--color-ink` | `#f3ece3` | `#1d1813` | Primary text |
| `--color-ink-soft` | `#a99c8c` | `#8c8073` | Secondary text |
| `--color-ink-faint` | `#74695c` | `#b0a597` | Tertiary / meta |
| `--color-hairline` | `#2c241c` | `#e3dccf` | Dividers / borders |
| `--color-accent` | `#ef6a20` | `#ec6a1e` | Spark / streak / links |
| `--color-cta-bg` / `--color-cta-ink` | orange `#ef6a20` / `#1c0f06` | ink `#34302a` / `#f4ede4` | Primary button |
| `--color-risk` (+ `-bg`, `-ink`) | amber `#d79a4e` | amber `#c2873a` | Weather-risk hero |
| `--color-factor-good / -mid / -high` | sage `#8a9966` / amber `#d79a4e` / clay `#cf7551` | sage `#7f8a5d` / amber `#c2873a` / clay `#bd6446` | Factor rings, trigger dots, severity |

Trigger levels map to factor colors: **high → clay/red, medium → amber, low → sage/green.**

### Typography
- **Serif (display):** `Source Serif 4` — screen titles, the weather-risk word, profile class. Optical sizing on.
- **Sans (UI/body):** `Hanken Grotesk` — everything else.
- Weights used: 400 / 500 / 600 / 700.
- Scale (px): `xs 11`, `sm 12.5`, `base 13.5`, `md 15`, `lg 19`, `title 34` (serif), `display 31` (serif).
- Line-heights: tight `1.06`, snug `1.4`, normal `1.55`. Tracking: tight `-0.015em`, snug `-0.01em`, wide `0.14em` (eyebrows/labels).

*(These px values are tuned to the prototype's 372×806 phone box — see Layout. Convert to the target platform's
type scale proportionally; keep the serif/sans split and weights.)*

### Spacing scale (px)
`1:4  2:6  3:9  4:11  5:14  6:16  7:20  8:22  10:30`

### Radii (px)
`xs 8` (tiny chips) · `sm 13` (icon buttons) · `md 14` (thumbnails / tab pills) · `lg 18` (primary buttons) ·
`xl 20` (factor cards) · `2xl 26` (hero cards) · `pill 999` · `screen 37` / `device 48` (phone frame — prototype chrome only).

### Elevation
Device shadow `0 30px 70px -30px rgba(0,0,0,.7)`. CTA glow (dark) `0 8px 26px -10px rgba(239,106,32,.6)`.
Keep shadows soft and warm; the UI is mostly flat with hairline borders doing the separation work.

### Icons
A single inline-SVG set (24×24 viewBox, 1.7–1.8px stroke, `currentColor`, round caps/joins). Full path list in
`prototypes/app/icons.jsx` (`PATHS` object). Names used: search, user, plus, home, cal, chart, cloud, cup,
plate, utensils, gauge, wind, droplet, thermo, sun, cloudcover, eye, bone, activity, alert, sound, moon, zap,
camera, type, check, x, chevL, chevR, trash, loader, sparkle, pin, flame, edit, book, trend, scale. Substitute
the target platform's equivalent icon set if preferred — match the light, rounded, outline style.

---

## Layout fundamentals
- Designed as a **single phone screen: 372 × 806 px** (the prototype scales this to fit the viewport; on device,
  use the real safe-area-aware screen size).
- Each screen = a vertical scroll `body` with ~`16px` horizontal padding, a fixed top bar, and a floating bottom
  nav. Content stacks with `gap`-based spacing.
- A custom iOS-style **status bar** (9:41, signal/wifi/battery) sits at the top of every screen — replace with the
  platform's real status bar.

---

## Screens / Views

### A. ONBOARDING FLOW (`Haven Onboarding.html` + `app/onboarding.jsx`)
A linear, back-navigable flow. The left "Onboarding flow" rail in the prototype is a **dev jump-menu — not part
of the product.** Step order is computed in `buildSteps()`:

**1. Welcome** — flame mark, serif headline "Find what's been triggering your migraines.", subcopy, primary
"Get started" CTA, and an "I already have an account" text button (jumps to the end).

**2–12. Question quiz** (11 questions, config in the `Q` array). Each screen has: a progress row (back chevron +
segmented progress bar + `n/total` step counter), a kicker label, a serif title, optional sub, the options, and a
sticky "Continue" footer CTA (disabled until answered). Two option layouts:
- **`list`** — full-width rows with optional leading icon, label, and a trailing check that fills when selected.
- **`grid`** — 2-column icon chips (used for multi-select symptoms & suspected triggers); the "not sure" option
  spans full width.

Questions: `frequency` (single), `duration`, `age`, `sex`, `cycle` *(conditional — only shown if sex ∈
female/intersex)*, `aura`, `symptoms` (multi grid), `severity`, `triggers` (multi grid + "not sure"), `meds`,
`goal` (multi list). Full option copy is in `app/onboarding.jsx` → `Q`.

**13. Synthesis** — two phases: a ~2.5s "Building your profile" loader (spinning orb + cycling status lines from
`SYN_LINES`), then a reveal card. The card derives a **profile class** ("Episodic/Chronic migraine [with aura]"),
**suspected-trigger chips**, and a "What Haven will watch for you" checklist — all computed from answers in
`buildProfile()` (chronic if frequency is `chronic`/`2-3wk`; aura if `often`/`sometimes`; adds a "Hormonal cycle"
watch row if the user opted to track their cycle). CTA: "Looks right".

**14. Weather permission** — cloud tile, "Let Haven watch the weather for you", explains barometric-pressure
triggers, "Enable location" primary CTA + "Not now" skip. (Primer screen — fire the real OS permission prompt
on tap.)

**15. Reminders permission** — bell tile, "One gentle nudge a day", a 2×2 time-of-day picker
(Morning 8:00 / Midday 12:30 / Evening 6:00 / Before bed 9:30), "Turn on reminders" + "Maybe later".

**16. Paywall** — flame mark, "Start finding your triggers", a 4-item feature list (AI trigger analysis,
barometric forecasts, unlimited history & doctor-ready reports, pattern insights), and two selectable plans:
**Yearly** ($83.20/yr → $1.60/wk, "SAVE 87% · 7 DAYS FREE" badge, default-selected) and **Weekly** ($12/wk).
CTA text switches: "Start 7-day free trial" (yearly) vs "Subscribe weekly". Restore/Terms/Privacy text links +
fine print. Has a close (×) that skips to done.

**17. Done** — check mark, "You're all set", copy varies if a trial started, "Enter Haven" → main app.

Flow state (`i`, `answers`, `plan`, `time`, `trial`) persists to `localStorage` key `haven.onboarding.v1`.

### B. MAIN APP (`Haven App.html` + `app/main.jsx`, `screens.jsx`, `sheets.jsx`, `data.jsx`)
Four tabs via the bottom nav. The nav has 5 slots: **Today** (shows today's date number), **Calendar**, a center
**＋ speed-dial**, **Insights**, **Weather**. The center ＋ fans out 4 quick-add actions (Food, Migraine, Symptom,
Daily factors) over a scrim, staggered in.

**Today** — top bar (title + date + streak flame chip + search/profile icon buttons); a tappable **weather-risk
hero** (label, big serif risk word "Elevated", a 4-bar gauge, headline + detail); **three factor rings**
(Sleep / Stress / Water, color-coded good/mid/high, tap to edit); two action buttons ("Log a migraine" primary,
"Snap a meal" ghost); an optional "Migraine today" danger alert card; a symptom/factors summary card; then the
"Logged today" food list (food cards) or an empty state.

**Food card** — thumbnail (photo or utensils icon), name, time, optional note, a delete button, and either a row
of **trigger chips** (colored dot + name + level) or a "No obvious triggers" clean state.

**Calendar** — month header with prev/next arrows, day-of-week row, a month grid. Each day cell shows the date and
a marker: a severity-colored ring if a migraine occurred, a dot if food was logged, a small dot if only symptoms.
Tapping a day opens a **Day Detail** bottom sheet (migraine alert, notes, food cards, summary).

**Insights** — three big stats (Migraine days / Days tracked / Triggers seen); a **ranked trigger list** — each
row shows rank number, trigger name, an "N migraines" or "no overlap" tag, a level-colored progress bar (share of
times eaten), and an "eaten N times" subline. Ranked by overlap with migraine days, then frequency. Closes with a
calm "A note on patterns" card framing triggers as hypotheses, not conclusions.

**Weather** — the risk hero again, then a 2×2 metric grid (Pressure swing with a sparkline of the falling trend,
Temp swing, Humidity, Wind) and a "Why this matters" explainer card. Pressure & temperature are presented as the
strongest signals; humidity is logged but de-emphasized.

**Bottom sheets** (`sheets.jsx`): all share a scrim + rounded-top sheet with a grab handle.
- **Log a migraine** — Mild/Moderate/Severe segmented control, notes textarea, Save; Remove if one exists.
- **Log symptoms** — 2-col multi-select grid (light, eye strain, neck, back, nausea, sound).
- **Daily factors** — Sleep slider (0–12h, 0.5 step), Stress & Hydration segmented (Low/Med/High), a
  "weather-sensitive today" toggle switch, Save.
- **Log food (capture)** — a **full-screen dark overlay** (forces `.theme-dark`). Two modes: **Photo**
  (file/camera input + a list of sample meals for demo) and **Describe** (textarea). "Analyze" runs the trigger
  engine (see below) with a ~900ms minimum "thinking" beat and a spinning loader, then shows a result view
  (label, note, per-trigger rows with dot + level + reason) → "Save to today" / "Redo".

---

## Interactions & Behavior
- **Theming:** dark default; a light theme exists. The prototype's floating "Light/Dark" + "Reset" buttons are
  **dev chrome** (`ProtoChrome`) — not product UI. Theme persists to `localStorage` `haven:theme`.
- **Speed-dial:** center ＋ toggles a fan of 4 actions over a scrim; items animate in staggered (45ms apart).
- **Sheets:** open over a tap-to-dismiss scrim; tapping the sheet body doesn't close it.
- **Food analysis:** see below. Always shows a brief "Analyzing" state even when the fallback is instant, so it
  feels considered.
- **Streak:** consecutive days (ending today) with any entry; shown as a flame chip in the Today top bar.
- **Calendar markers** are derived from each day's log (migraine severity → ring color; food/symptoms → dots).
- **Reduced motion / print:** the prototype's entrance animations should degrade gracefully — don't gate content
  visibility on animation.

## Food-trigger analysis (`data.jsx`)
Two-tier. It first tries a real LLM call (`window.claude.complete` in the prototype — replace with your backend's
LLM endpoint) using `ANALYSIS_PROMPT`, which asks for minified JSON: `{label, triggers:[{name, level, reason}], note}`
with `level ∈ high|medium|low`. **On any failure it falls back to `fallbackAnalyze()`** — an offline keyword/regex
engine (aged cheese→tyramine, cured meat→nitrates, alcohol, MSG, chocolate, caffeine, sweeteners, citrus,
fermented/yeast, nuts, tomato, soy sauce). Triggers are sorted high→low. **Keep the offline fallback** — trigger
analysis must work without a network round-trip.

## State Management
Prototype uses React state + `localStorage`. For production, model:
- **Daily log** keyed by `YYYY-MM-DD`: `{ foods:[{id,label,time,note,thumb,triggers:[{name,level,reason}]}],
  migraine:{had,severity,time,notes}, symptoms:[key], factors:{sleep,stress,hydration,weatherSensitive} }`.
- **Onboarding answers** (the `Q` ids above) → drive the synthesis profile.
- **Settings:** theme, reminder time, subscription/plan/trial state.
- **Weather** is mocked deterministically (`mockWeather()`) — wire to a real barometric API; the UI expects
  `{level, bars, swing, tempSwing, humidity, temp, trend[], headline, detail}`.
Seed/demo data lives in `seedData()` — useful as fixtures, not for production.

## Assets
- **Fonts:** Source Serif 4 + Hanken Grotesk (Google Fonts). Bundle the platform-appropriate versions.
- **Icons:** inline SVG set in `app/icons.jsx` (see Icons above).
- **Food photos:** user-supplied via camera/upload; the prototype downscales to a ~180px JPEG thumbnail.
- No raster brand assets — the "logo" is the `flame` icon on an orange tile.

---

## Files in this handoff (`prototypes/`)
| File | What it is |
|---|---|
| `Haven App.html` | Main app entry (loads the CSS + the `app/*.jsx` below) |
| `Haven Onboarding.html` | Onboarding flow entry + flow orchestrator (inline) |
| `haven-tokens.css` | **Design system — port this first.** Primitives, global tokens, dark/light themes |
| `haven-components.css` | Shared component styles consuming the tokens |
| `haven-app.css` | App-screen-specific styles (Today/Calendar/Insights/Weather/nav/sheets) |
| `onboarding.css` | Onboarding-specific styles |
| `app/icons.jsx` | Inline SVG icon set (`PATHS` + `Icon`) |
| `app/data.jsx` | Data layer: storage, seed data, mock weather, food-trigger engine |
| `app/screens.jsx` | The four app screens + shared atoms (StatusBar, TopBar, RiskHero, FoodCard…) |
| `app/sheets.jsx` | Bottom sheets, day detail, log-food capture, bottom nav + speed-dial |
| `app/main.jsx` | App root, state, mutations, theming, mount/scale (prototype only) |
| `app/onboarding.jsx` | All onboarding screens + question config + profile synthesis |

### Not included (intentionally)
- `Haven Refined.html` — an early token-system showcase scaffold, superseded.
- `Haven Coverage Board.html` + `board.jsx` + `design-canvas.jsx` — a side-by-side presentation wrapper of the
  same screens, for review only (not product surfaces).
- Working screenshots and the original source uploads (migraine reference shots, feature brief) — available
  separately if useful as product context.
