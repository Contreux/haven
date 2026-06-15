# Scan Menu — Design

**Goal:** From the Today action fan, the user photographs a restaurant menu. Claude vision reads each dish, classifies it Safe / Caution / Avoid against migraine triggers (weighted by the user's suspected trigger categories), and shows an adaptive "can eat / can't eat" breakdown. Tapping a dish logs it to today.

**Approach:** Mirror the existing food-photo vision stack end-to-end — Convex vision `action` → pure parser → tolerant Codable model → `DayDataSource` / `TodayStore` / `ConvexService` → SwiftUI sheet launched from `SpeedDial`.

**Tech stack:** SwiftUI (iOS 17), HavenCore (Swift), Convex (TypeScript) + Anthropic Messages API (Claude Haiku 4.5 vision).

---

## Decisions (locked)

1. **Verdict basis — Personalized.** Start from the same generic migraine-trigger guide the food logger uses (`TRIGGERS_GUIDE` in `convex/ai.ts`), but weight/emphasize the trigger categories the user picked during onboarding (the `triggers` answer: food, alcohol, caffeine, weather, stress, sleep, dehydration, skipped). Note: onboarding captures coarse *categories*, not a fine-grained personal food list — personalization = weighting, not a bespoke per-user list.
2. **Verdict tiers — Three: Safe / Caution / Avoid.**
3. **After scan — Tap any dish to log it** as a `FoodEntry` to today, reusing the existing food save path.

## Adaptive display rule

- `canEat = safe + caution`, `cantEat = avoid`.
- **Lead with whichever list is shorter** (the more actionable one): more dishes you can eat → highlight the few to avoid; more to avoid → highlight the few you can eat. On a tie, lead with `canEat`.
- Both lists always render; `lead` only controls order/emphasis.

## Architecture

### 1. Backend (Convex)

- **`convex/menuParse.ts`** (new) — pure `parseMenuAnalysis(text, fallbackName)` returning
  `{ dishes: [{ name: string, verdict: "safe"|"caution"|"avoid", triggers: string[], reason: string }] }`.
  - Strips ```` ```json ```` fences, `JSON.parse`.
  - Reuses the `LEVELS`-style normalization idea from `foodParse.ts`: map `verdict` via a table (`safe→safe`, `caution|warn|mid|medium→caution`, `avoid|high|danger→avoid`), default `caution`.
  - Coerces `triggers` to a string array, drops empties.
  - Clamps `name` (≤ 48 chars) and `reason` (≤ 60 chars); caps `dishes` at 30.
  - Drops dishes with an empty `name`.
- **`convex/ai.ts`** — new `scanMenu` action, args `{ imageBase64: v.string(), suspected: v.optional(v.array(v.string())) }`. Reuses `callClaude(content)` with a vision image content block (`media_type: "image/jpeg"`). Prompt:
  > "This is a photo of a restaurant menu. List each distinct dish you can read. For each dish classify it for a migraine sufferer as safe / caution / avoid using: {TRIGGERS_GUIDE}. The user especially suspects these trigger categories: {suspected}. Weight those higher when in doubt. Reply with ONLY minified JSON, no markdown: {"dishes":[{"name":"...","verdict":"safe|caution|avoid","triggers":["aged cheese"],"reason":"short reason under 8 words"}]}. If a dish has no likely trigger use verdict "safe", triggers []."

  `max_tokens` raised (menus list many dishes) to ~1500. Returns `parseMenuAnalysis(await callClaude(content), "Dish")`.

### 2. HavenCore

- **`MenuScan.swift`** (new):
  - `public enum DishVerdict: String, Codable, Sendable { case safe, caution, avoid }` with tolerant `init(from:)` (unknown → `.caution`).
  - `public struct MenuDish: Codable, Sendable, Equatable, Identifiable { id = name; name; verdict; triggers: [String]; reason: String }` with tolerant decoding (missing arrays → `[]`, missing strings → `""`).
  - `public struct MenuScan: Codable, Sendable, Equatable { dishes: [MenuDish] }`.
  - Pure helper:
    ```swift
    enum Lead { case canEat, cantEat }
    func grouped() -> (canEat: [MenuDish], cantEat: [MenuDish], lead: Lead)
    ```
    `canEat = dishes.filter { $0.verdict != .avoid }`, `cantEat = dishes.filter { $0.verdict == .avoid }`.
    Lead with the **shorter** list: `lead = cantEat.count < canEat.count ? .cantEat : .canEat` (tie → `.canEat`).
- **`DayDataSource`** — add `func scanMenu(imageBase64: String, suspected: [String]) async throws -> MenuScan`. Implement stub in `FakeSource` (tests) returning a fixed `MenuScan`.
- **`TodayStore`** — add `func scanMenu(imageBase64: String) async -> MenuScan`:
  - Derives `suspected` from the loaded onboarding answers (`answers["triggers"]`, excluding `"unsure"`); empty array if none.
  - `try await source.scanMenu(imageBase64:suspected:)`; on thrown error returns `MenuScan(dishes: [])` (sheet treats empty as "couldn't read"). No on-device fallback — vision is required (unlike food, which can fall back to `TriggerEngine`).

### 3. Haven app

- **`ConvexService.scanMenu(imageBase64:suspected:)`** — calls the `ai:scanMenu` action, decodes into `MenuScan`.
- **`SpeedDial.swift`** — add `case menu` to `LoggerKind`; new fan item `(.menu, "Scan menu", "doc.text.viewfinder")` (placed first or last in the list — last, after "Daily factors").
- **`RootTabView.swift`** — handle `.menu` pick → present new `MenuScanSheet` (`.sheet`); wire `scanMenu: { data in await store.scanMenu(imageBase64: data.base64EncodedString()) }` and `onLog:` reusing the existing food save (`store.addFood` with a `FoodEntry`).
- **`MenuScanSheet.swift`** (new, `Sources/Today/Loggers`):
  - `SheetHeader(title: "Scan menu", subtitle: "Photo a menu — see what's safe")`.
  - `PhotosPicker` (images) → on change, `ImageScaler.downscaledJPEG(raw)` into `imageData`.
  - "Scan menu" CTA (disabled until a photo is attached) → `busy` spinner → `result = await scanMenu(data)`.
  - **Results:** if `result.dishes.isEmpty` → "Couldn't read that menu — try a clearer, well-lit photo." + Redo.
    Else summary line ("`{dishes.count} dishes · {canEat.count} you can eat`"), then render the **lead** list first with a section header ("YOU CAN EAT" / "BEST TO AVOID"), then the other list. Verdict dot: Safe = green, Caution = amber (+ reason), Avoid = red (+ reason). Reuse `LevelDot` style or a small colored circle.
  - **Tap a dish row** → logs `FoodEntry(name: dish.name, time: TodayStore.nowHM(), triggers: <mapped from dish.triggers>, note: "From menu scan", imageId: nil)` via `onLog`, shows an inline "Logged ✓" on that row (does not dismiss, so the user can log several).
  - Footer disclaimer: "Assessments are informational and may be wrong." (same copy as the food sheet).
  - `accessibilityIdentifier`s: `menu-scan` (CTA), `menu-dish-{index}` (rows).

### 4. Mapping dish triggers → `FoodEntry.triggers`

`MenuDish.triggers` is `[String]` (names only). For logging, map each name to a `TriggerChip` with a level derived from the dish verdict (`avoid→high`, `caution→mid`, `safe→` no chips). Keep it simple: a small pure helper `MenuDish.asTriggerChips()` in HavenCore so it is unit-testable.

## Error handling

- No `ANTHROPIC_API_KEY` / Anthropic non-200 / malformed JSON / unreadable photo → action throws or parser throws → `TodayStore.scanMenu` returns `MenuScan(dishes: [])` → sheet shows the "couldn't read" state. No crash, no on-device fallback.

## Testing (TDD)

- **HavenCore (XCTest):**
  - `MenuScan` / `MenuDish` / `DishVerdict` tolerant decoding (missing fields, unknown verdict → caution).
  - `grouped()` lead logic: more-safe → lead `.canEat`; more-avoid → lead `.cantEat`; tie → `.canEat`; all-safe; all-avoid.
  - `MenuDish.asTriggerChips()` mapping by verdict.
  - `FakeSource.scanMenu` stub + `TodayStore.scanMenu` delegation (passes suspected categories, returns source value; error → empty scan).
- **Convex:** `parseMenuAnalysis` — unit test if a JS test runner is already wired in `package.json`; otherwise keep it defensively coded and exercised through the Swift `FakeSource`. (Confirm during planning.)

## Out of scope (YAGNI)

OCR/menu text editing, saving the scan itself as a record, multi-photo menus, dietary filters beyond migraine triggers, the v1.1 paywall gate.
