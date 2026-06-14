# Haven — Milestone 2: Logging (Design Spec)

**Date:** 2026-06-14
**Status:** Approved for planning (standing authorization — "keep going until finished")
**Milestone:** 2 of 5 (Today/ledger shipped in M1)

---

## 1. Goal

Let the user **record** everything the Today ledger renders: a migraine, symptoms, daily factors, and food (with AI trigger analysis). Every logger writes to Convex and the Today screen updates reactively through the existing `getDay` subscription. This makes Haven actually usable day-to-day — M1 could only display seeded data and edit factors; M2 adds the full capture surface.

### Non-goals (deferred)
Calendar / Insights tabs + the full bottom nav (M3) · real barometric weather (M4) · onboarding / paywall / real auth (M5). M2 adds the loggers and a center "+" speed-dial entry point, **not** the four-tab bottom navigation.

---

## 2. Confirmed decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Food analysis | **Two-tier**: `analyzeFood` Convex action (LLM) + on-device Swift keyword fallback. Must work with no key. |
| 2 | LLM model | **Claude Haiku 4.5** (`claude-haiku-4-5-20251001`) via `ANTHROPIC_API_KEY` Convex env var; degrades to on-device engine when absent. |
| 3 | Food photos | **Convex file storage** (`generateUploadUrl` + `storage.getUrl`); `imageId` stored on the food entry. Optional — describe-only also works. |
| 4 | Factors logger | The **polished** sheet (slider + segmented + switch) replaces M1's minimal `FactorEditor`; still calls `setFactors`. |
| 5 | Entry points | Today action buttons + a center **"+" speed-dial** fan (Food / Migraine / Symptom / Daily factors). Full tab bar is M3. |
| 6 | Schema changes | **Additive only** — keep M1 seed/data valid: `TriggerChip.reason?`, `FoodEntry.note?`, `FoodEntry.imageId?`. |

---

## 3. Architecture overview

```
Today screen (M1) ── "+" speed-dial / action buttons ──┐
                                                        ▼
            ┌───────────── bottom-sheet loggers ─────────────┐
            │ MigraineSheet  SymptomSheet  FactorsSheet  FoodCaptureSheet │
            └───────┬───────────┬────────────┬──────────────┬────────────┘
                    │ store write methods (TodayStore + DayDataSource)     │
                    ▼                                                       ▼
        Convex mutations: setMigraine/removeMigraine,            analyzeFood ACTION (LLM)
        setSymptoms, setFactors(existing), addFood/removeFood     ├─ key present → Claude Haiku
        + file storage (generateUploadUrl)                        └─ error/no key → on-device
                    │                                                TriggerEngine (HavenCore)
                    ▼
              days doc updated → getDay subscription echoes → ledger re-derives
```

HavenCore stays headless-testable: the `TriggerEngine` (keyword rules) and the extended models live there with unit tests. The `analyzeFood` network call lives in `ConvexService` (the only ConvexMobile importer); the two-tier orchestration (try action, catch → engine) is a `TodayStore`/service method tested via the fake.

---

## 4. Data model changes (additive)

`convex/schema.ts` — extend the embedded shapes (all new fields optional so M1 docs remain valid):

```ts
triggerChip = v.object({ label: v.string(), level, reason: v.optional(v.string()) })
foodEntry   = v.object({
  name: v.string(), time: v.string(), triggers: v.array(triggerChip),
  note: v.optional(v.string()),
  imageId: v.optional(v.id("_storage")),   // Convex file storage ref
})
```

`days.migraine` and `days.symptoms` already exist. No new tables.

HavenCore models gain the matching optional fields: `TriggerChip.reason: String?`, `FoodEntry.note: String?`, `FoodEntry.imageId: String?` (decoded as the storage id string; the URL is resolved server-side or via a `getImageUrl` query in a later pass — M2 stores the id and shows the thumb when a URL is available).

---

## 5. Backend — Convex functions

| Kind | Name | Purpose |
|---|---|---|
| mutation | `setMigraine(userId, date, migraine)` | Upsert the day's migraine sub-record. |
| mutation | `removeMigraine(userId, date)` | Clear it (set `had:false`/undefined). |
| mutation | `setSymptoms(userId, date, symptoms, loggedAt)` | Upsert symptoms + timestamp. |
| mutation | `addFood(userId, date, food)` | Append a food entry to the day. |
| mutation | `removeFood(userId, date, foodIndex)` | Remove one food entry. |
| mutation | `generateUploadUrl()` | Convex file-storage upload URL for a photo. |
| query | `getImageUrl(imageId)` | Resolve a storage id → URL for display. |
| action | `analyzeFood(description)` | LLM trigger analysis; returns `{label, triggers, note}`. |

All day mutations follow the existing upsert pattern (find by `by_user_date`, patch-or-insert), scoped by device `userId`. Each covered by `convex-test`. The `analyzeFood` action reads `process.env.ANTHROPIC_API_KEY`; if missing or the call/parse fails, it throws (the client then uses the on-device engine) — keep the action thin and deterministic to test (mock the fetch, or test only the parse/shape with the key absent → throws).

**`analyzeFood` contract** (matches the handoff): returns minified JSON
`{"label": "...", "triggers":[{"name","level","reason"}], "note":"..."}`, `level ∈ {high,medium,low}` mapped to our `low|mid|high` on the client (medium→mid).

---

## 6. On-device fallback — `TriggerEngine` (HavenCore)

A pure port of the handoff's `fallbackAnalyze` keyword rules:

```swift
public struct AnalyzedFood: Sendable, Equatable {
    public let label: String
    public let triggers: [TriggerChip]   // reuses the model (with reason)
    public let note: String
}
public enum TriggerEngine {
    public static func analyze(_ text: String) -> AnalyzedFood
}
```

Rules table ported verbatim (cheese→Aged cheese/high, wine|beer|alcohol→Alcohol/high, cured meats→high, MSG→high, soy sauce→mid, chocolate→mid, caffeine→mid, sweetener→mid, citrus→low, fermented/yeast→low, nuts→low, tomato→low). Sorted high→mid→low. Label = trimmed/capitalized text (≤42 chars). Fully unit-tested (cheese detected high, clean food → empty, ordering, label formatting). The LLM `level` "medium" maps to our `.mid`.

---

## 7. Client — loggers & wiring

All sheets are tokenized SwiftUI (`HavenDesignSystem`), presented via `.sheet`, writing through new `TodayStore` methods that call `DayDataSource` (so they're testable with the fake and backed by `ConvexService`).

### 7.1 Sheets
- **MigraineSheet** — title + date, severity `Segmented(Mild/Moderate/Severe)`, notes `TextEditor`, Save → `setMigraine`; Remove (when existing) → `removeMigraine`.
- **SymptomSheet** — 6 toggle buttons (light/eye/neck/back/nausea/sound) in a grid; Save → `setSymptoms` (+ `nowHM`). Symptom catalog with SF Symbol mapping.
- **FactorsSheet** — sleep slider (0–12, 0.5), stress/hydration `Segmented(Low/Mid/High)`, weather-sensitive `Toggle`; Save → `setFactors`. Replaces M1's `FactorEditor` (delete it; rings now open this).
- **FoodCaptureSheet** — modes Photo / Describe. Photo: `PhotosPicker` (library; camera is device-only) → upload via `generateUploadUrl`. Describe: text field. **Analyze** → two-tier (`analyzeFood` action, catch → `TriggerEngine`) → result view (label, note, trigger rows with level dots + reasons) → **Save to today** → `addFood`. "Redo" resets.

### 7.2 Reusable components (HavenDesignSystem or app)
`Segmented` (token-styled segmented control), `LevelDot` (factor-color dot by level), `SheetHeader` (title + date + grab handle). These are small, focused, reused across sheets.

### 7.3 Entry points
- A center **"+" speed-dial**: a bottom-center button that fans Food / Migraine / Symptom / Daily factors (per `BottomNav` in the handoff). Tapping one opens its sheet.
- Today's existing **"Log a migraine"** → MigraineSheet, **"Snap a meal"** → FoodCaptureSheet (replacing the M2-deferred no-ops).
- The dev theme-toggle FAB moves to make room (or is kept until M3's nav/settings lands) — minor chrome, not load-bearing.

### 7.4 Store methods (TodayStore)
`saveMigraine`, `removeMigraine`, `saveSymptoms`, `saveFood`, `removeFood`, and `analyze(_ text:) async -> AnalyzedFood` (two-tier). All route through `DayDataSource` (extended protocol). Reactive: each write echoes back via `observeDay` → ledger re-derives → sheets dismiss.

---

## 7.5 Decomposition (two plans)

- **M2-P1 — Backend + core logic:** schema extensions; mutations (`setMigraine`/`removeMigraine`/`setSymptoms`/`addFood`/`removeFood`/`generateUploadUrl`/`getImageUrl`); `analyzeFood` action; HavenCore model extensions + `TriggerEngine` + extended `DayDataSource`/`TodayStore` methods + the two-tier `analyze`. All `convex-test` + `swift test` covered. Produces a backend + core layer the UI plugs into.
- **M2-P2 — Logger UI:** `Segmented`/`LevelDot`/`SheetHeader`; the four sheets; the "+" speed-dial; entry-point wiring; `ConvexService` implementations of the new `DayDataSource` methods + the `analyzeFood` call; Maestro verification. Produces the working logging surface.

---

## 8. Testing strategy

| Layer | Test |
|---|---|
| Convex | upsert semantics for each mutation (create + update + scope); `analyzeFood` shape/throws-without-key. |
| HavenCore | `TriggerEngine` rules (detect/clean/order/label); extended model decode (food with note/imageId/reason; back-compat with M1 JSON); `TodayStore` two-tier `analyze` (action success path + fallback path via fake); each new write method round-trips via fake. |
| Enforcement | token guard stays green across new sheets. |
| UI (Maestro) | open each logger from the speed-dial, save, see the ledger update; food: describe → analyze → save → ledger row with triggers. |

---

## 9. Definition of done

1. From Today, the user can open all four loggers (speed-dial + action buttons) and save each; the ledger updates reactively (verified on simulator via Maestro).
2. Food: describe a meal → Analyze → trigger list → Save → appears in the ledger with trigger chips. Works with NO API key (on-device engine); uses Claude when `ANTHROPIC_API_KEY` is set.
3. M1 data/seed still decodes (additive schema/model changes).
4. All tests pass (Convex, HavenCore, design-system); token guard clean.

---

## 10. Open risks
- **convex-swift `action` call** — same client as `mutation`; verify `client.action(_:with:)` decodes the `analyzeFood` JSON into a Swift `AnalyzedFood`-shaped Decodable (or decode the raw and map). Verify against the installed package as the first step of P2.
- **Photo capture in simulator** — no camera; use `PhotosPicker` (library) + describe mode for Maestro. Camera is device-only, untested in CI.
- **LLM JSON robustness** — the action must defensively parse (strip markdown fences) and throw on bad shape so the client falls back cleanly. Tested by shape, not live calls.
