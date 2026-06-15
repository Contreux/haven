# Food Photo Vision Analysis — Design

**Date:** 2026-06-15
**Status:** Approved (build it)

## Goal

Make "Snap a meal" genuinely AI-powered: the **photo itself** is analyzed by Claude vision, which **pulls out the data** — identifying each food/drink item in the picture and flagging migraine triggers across them. Today the photo is only stored; classification is text-only.

## Decisions (locked)

- **Model:** Claude **Haiku 4.5** (multimodal) — fires on every meal photo, so cost/speed win.
- **Extraction:** **Itemized + triggers** — a list of detected items (e.g. "Cheeseburger", "Fries", "Cola") plus ranked trigger chips.
- **Transport:** client **downscales** the photo (max ~1024px JPEG) and sends it **base64** to a Convex action (well within arg limits; cheaper/faster for vision). The existing storage upload on save is unchanged and reuses the same downscaled bytes.
- **Fallback:** unchanged two-tier philosophy — if the vision action fails (no `ANTHROPIC_API_KEY`, network, bad JSON), fall back to the on-device `TriggerEngine` running on the typed hint (no hint ⇒ no triggers). Vision is server-only; the on-device engine stays text-only.

## Data model

`AnalyzedFood` (HavenCore) gains `items: [String]`:

```swift
public struct AnalyzedFood: Codable, Sendable, Equatable {
    public let label: String
    public let items: [String]        // NEW — detected foods/drinks
    public let triggers: [TriggerChip]
    public let note: String
}
```

Decoding must **tolerate a missing `items`** (the text action and older responses don't send it) via a custom `init(from:)` defaulting to `[]`. `TriggerEngine.analyze` sets `items: []` (keyword engine doesn't itemize). `AnalyzedFood` is transient (never persisted), so no migration.

## Convex

- **`convex/foodParse.ts`** (new, NOT "use node" — pure, testable): `parseAnalysis(text: string, fallbackLabel: string): { label, items, triggers, note }`. Strips markdown fences, `JSON.parse`, normalizes trigger levels (`medium→mid`), coerces `items` to a string array, clamps label to 42 chars. Both actions use it. Unit-tested.
- **`convex/ai.ts`**:
  - Refactor the existing text `analyzeFood` to use `parseAnalysis` (DRY; behavior unchanged).
  - Add **`analyzeFoodImage`** action (`"use node"`): args `{ imageBase64: v.string(), hint: v.optional(v.string()) }`. Throws if `ANTHROPIC_API_KEY` unset. Calls Claude Haiku 4.5 with an **image content block** (`type:"image"`, base64, `media_type:"image/jpeg"`) + the trigger prompt (and the hint if present), instructing it to list `items` and `triggers`. Returns `parseAnalysis(...)`.

Vision prompt shape (JSON only): `{"label","items":["..."],"triggers":[{"name","level","reason"}],"note"}`.

## Client (SwiftUI)

- **`Haven/Sources/Today/Loggers/ImageScaler.swift`** (new): `ImageScaler.downscaledJPEG(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.6) -> Data` (UIKit). Used when a photo is picked, so analysis + storage both use the small version.
- **`FoodCaptureSheet`**: when the picker loads an image, store the **downscaled** bytes. The **Analyze** button: if a photo is attached → call the new image path; else the existing text path. **Result view** gains an "ITEMS DETECTED" section listing `r.items` (shown only when non-empty), above the triggers. Save flow unchanged (uploads the downscaled bytes).
- **`DayDataSource`** gains `analyzeFoodImage(imageBase64: String, hint: String) async throws -> AnalyzedFood`; implemented in `ConvexService` (`client.action("ai:analyzeFoodImage", ...)`) and stubbed in the `FakeSource` test double (same task, to keep the build green).
- **`TodayStore`** gains `analyzeImage(imageBase64: String, hint: String) async -> AnalyzedFood` — two-tier: try `source.analyzeFoodImage`, on error `TriggerEngine.analyze(hint)`.
- **`RootTabView`** passes an `analyzeImage` closure into `FoodCaptureSheet` (encoding `Data → base64` there) alongside the existing `analyze`.

## Error handling
- No key / network / bad JSON ⇒ graceful fallback to the on-device engine on the hint (existing pattern), surfaced as a normal (possibly empty) result — never an error to the user.
- Downscale failure ⇒ fall back to sending the original bytes (still works, just larger).

## Testing
- **Convex:** `foodParse.test.ts` — parses itemized JSON, tolerates markdown fences, normalizes levels, empty triggers, missing items ⇒ `[]`. Plus `analyzeFoodImage` throws without a key (mirrors the existing `analyzeFood` test).
- **HavenCore:** `AnalyzedFood` decodes with `items` present and absent (defaults `[]`); `TriggerEngine.analyze` returns `items: []`.
- **App:** build green; the live image→Claude path needs a key + real photo, so it's verified manually (Maestro can't supply a camera image). The describe-mode text path and fallback remain Maestro-covered.

## Out of scope (follow-ups)
- Per-item portion/quantity estimation.
- Re-analyzing an already-saved photo from history.
- On-device (offline) vision.
