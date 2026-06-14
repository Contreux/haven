# HavenDesignSystem

The **single source of truth** for Haven's look and feel — colors, typography, spacing, radii, and
elevation. It is a standalone Swift module: change the values here and the whole app re-skins.

It is a faithful port of `design_handoff/prototypes/haven-tokens.css`. When the two ever disagree,
the token CSS is the design source of truth and this module should be reconciled to it.

---

## Why a separate module

Centralisation is **enforced by the module boundary**, not by convention:

- **Primitives are `internal`** to this module — raw hex codes and magic numbers live *only* here and
  are invisible to the rest of the app.
- **Feature targets depend only on the `public` API** — semantic tokens, the type scale, spacing,
  radii. They *cannot compile* a reference to a raw hex or a bare number.
- Result: there is no "back door" for a hardcoded color. The only way to change the look is to edit
  this module. That's what makes "everything connects to the design system" a compile-time guarantee
  rather than a code-review hope.

A grep guard in pre-commit/CI backs this up by failing on `Color(`, `UIColor(`, `.font(.system`, or
bare numeric literals in feature targets (this module is allow-listed).

---

## Architecture — three layers

Mirrors the CSS file exactly.

```
┌── Layer 1 · PRIMITIVES (internal) ──────────────┐
│  Raw values. The ONLY place literal hex/px live.│  --p-orange-500 → Primitives.orange500
│  Not visible outside this module.               │
└─────────────────────────────────────────────────┘
            │ mapped by
┌── Layer 2 · GLOBAL TOKENS (public) ─────────────┐
│  Theme-agnostic: Spacing, Radius, TypeScale,    │  Spacing.s6, Radius.xl, TypeScale.title
│  weights, leading, tracking, elevation.         │
└─────────────────────────────────────────────────┘
            │ + theme-varying colors
┌── Layer 3 · THEME (public) ─────────────────────┐
│  Semantic tokens that swap dark/light:          │  theme.ink, theme.accent, theme.factorHigh
│  Theme.dark  /  Theme.light                     │
└─────────────────────────────────────────────────┘
            │ injected once at the root
        @Environment(\.theme)  ← every view reads from here
```

**Rule: views consume only Layer 2 + Layer 3. Never Layer 1.**

---

## Layer 1 — Primitives (`internal`)

The only literals in the codebase. Names mirror the `--p-*` tokens. Examples:

| Group | Tokens |
|---|---|
| Brand orange | `orange600 #ec6a1e` · `orange500 #ef6a20` · `orange300 #e89766` · `orangeInk #1c0f06` |
| Warm charcoal | `charcoal950 #15110d` … `charcoal900 #1c1712` … `charcoal820 #272019` … `charcoal780 #2c241c` |
| Cream / sand | `cream50 #f4ede4` · `cream100 #f3ece3` · `sand500 #a99c8c` · `taupe600 #74695c` |
| Warm paper | `paper50 #f1ece4` · `paper100 #e7e0d6` · `ink900 #1d1813` · `stone500 #8c8073` |
| Semantic hues | `sageDark #8a9966` / `sageLight #7f8a5d` · `amberDark #d79a4e` / `amberLight #c2873a` · `clayDark #cf7551` / `clayLight #bd6446` |

> The brand orange is a **spark used sparingly** (accent/CTA only). Every neutral is warm-toned —
> **no cold grays.**

---

## Layer 2 — Global tokens (`public`, theme-agnostic)

Exact values from the token file, expressed as points.

**Spacing** — `s1 4 · s2 6 · s3 9 · s4 11 · s5 14 · s6 16 · s7 20 · s8 22 · s10 30`

**Radius** — `xs 8 · sm 13 · md 14 · lg 18 · xl 20 · xxl 26 · pill 999`
*(the 372×806 phone-frame radii — `screen 37`, `device 48` — are prototype chrome and are omitted)*

**Typography**
- Families: **serif** = Source Serif 4 (display) · **sans** = Hanken Grotesk (UI/body)
- Weights: `regular 400 · medium 500 · semibold 600 · bold 700`
- Sizes (pt): `xs 11 · sm 12.5 · base 13.5 · md 15 · lg 19 · title 34 (serif) · display 31 (serif)`
- Leading: `tight 1.06 · snug 1.4 · normal 1.55`
- Tracking (em): `tight -0.015 · snug -0.01 · wide 0.14`

**Elevation** — soft, warm shadows; the UI is mostly flat with hairline borders doing the separation.
The CTA glow is theme-specific (see below).

---

## Layer 3 — Theme (`public`, varies dark/light)

A `Theme` struct of semantic color tokens, with two instances mapping the primitives per
`.theme-dark` / `.theme-light`. **Dark is the default.**

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `charcoal900` | `paper50` | App background |
| `surface` / `chip` | `charcoal820` | `paper100` | Cards / chips / sheets |
| `ink` | `cream100` | `ink900` | Primary text |
| `inkSoft` | `sand500` | `stone500` | Secondary text |
| `inkFaint` | `taupe600` | `stone400` | Tertiary / meta |
| `hairline` | `charcoal780` | `paper200` | Dividers / borders |
| `track` | `charcoal760` | `paper300` | Gauge / progress track |
| `accent` | `orange500` | `orange600` | Spark / streak / links |
| `streakBg` | `orange500 @14%` | `paperPeach` | Streak chip background |
| `risk` / `riskBg` / `riskInk` | `amberDark` / `amberDark @15%` / `amberInkDark` | `amberLight` / `#f0e2cd` / `amberInkLight` | Weather-risk hero |
| `ctaBg` / `ctaInk` | `orange500` / `orangeInk` | `ink700` / `cream50` | Primary button |
| `ctaShadow` | `0 8px 26px -10px orange@60%` | `0 8px 22px -12px ink@50%` | CTA glow |
| `tabbarBg` / `tabActiveBg` / `tabActiveInk` | `charcoal900 @86%` / `charcoal800` / `cream100` | `paper50 @86%` / `#2f2a24` / `cream100` | Bottom nav |
| `factorGood` / `factorMid` / `factorHigh` | `sageDark` / `amberDark` / `clayDark` | `sageLight` / `amberLight` / `clayLight` | Factor rings, trigger dots, severity |

**Trigger / severity → color:** `high → factorHigh` (clay) · `medium → factorMid` (amber) ·
`low → factorGood` (sage). Use the provided `Theme.factorColor(for:)` helper, never a raw mapping.

---

## Typography as tokens — `TextStyle`

A `TextStyle` bundles family + size + weight + leading + tracking. Named styles cover the
prototype's usage; one modifier applies font + kerning + line-spacing + a semantic color.

| Style | Spec |
|---|---|
| `.screenTitle` | serif · title 34 · leading tight · tracking tight |
| `.riskWord` | serif · display 31 |
| `.sectionHead` | sans · md 15 · semibold |
| `.body` | sans · base 13.5 |
| `.meta` | sans · sm 12.5 |
| `.columnLabel` | sans · lg 19 |
| `.eyebrow` | sans · xs/sm · tracking wide · uppercased |

```swift
Text("Today").havenText(.screenTitle, color: theme.ink)
```

- **Kerning** = `tracking_em × size`. **Line-spacing** ≈ `size × (leading − 1)`.
- Fonts bundled in `Resources/Fonts/` (Source Serif 4 variable + Hanken Grotesk) and registered via
  `UIAppFonts`. Source Serif 4 uses optical sizing.
- **Dynamic Type:** sizes scale via `UIFontMetrics`; spacing/radii stay fixed.

---

## Theming & configurability

```swift
@Observable public final class ThemeController {
    public var mode: ThemeMode = .dark      // default; persisted (UserDefaults → later, user settings)
    public var theme: Theme { mode == .light ? .light : .dark }
}
```

Inject once at the root:

```swift
ContentView().environment(\.theme, themeController.theme)
```

Every view reads `@Environment(\.theme)`, so flipping `mode` re-skins the **entire app** from a
single value. That runtime behavior is the proof the system is genuinely centralised.

---

## Usage rules (for feature code)

✅ **Do**
```swift
RoundedRectangle(cornerRadius: Radius.xl)
    .fill(theme.surface)
    .padding(Spacing.s6)
Text(label).havenText(.sectionHead, color: theme.ink)
```

🚫 **Don't** (these won't compile in feature targets, and the guard script blocks them anyway)
```swift
.fill(Color(hex: 0x272019))     // raw hex — Primitives are internal
.padding(16)                    // magic number — use Spacing.s6
.font(.system(size: 15))        // bypasses the type scale — use .havenText
```

---

## Changing the look

1. **A single value** (e.g. a warmer accent): edit the primitive in Layer 1.
2. **A semantic role** (e.g. cards get a new surface): edit the mapping in `Theme.dark`/`.light`.
3. **A new token**: add it to the relevant layer's `public` API, then consume it.

You should never need to touch feature code to restyle the app.

---

## Map to the source

| This module | CSS source |
|---|---|
| `Primitives` | `:root` `--p-*` block |
| `Spacing`, `Radius`, `TypeScale`, weights, leading, tracking | `GLOBAL TOKENS` block |
| `Theme.dark` | `.theme-dark` |
| `Theme.light` | `.theme-light` |

Full design intent — screen behavior, copy, the icon set — lives in
[`../design_handoff/README.md`](../design_handoff/README.md). See also the M1 spec:
[`../docs/superpowers/specs/2026-06-14-haven-m1-foundation-today-design.md`](../docs/superpowers/specs/2026-06-14-haven-m1-foundation-today-design.md).
