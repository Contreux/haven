# Menu Scanner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Scan menu" action to the Today action fan that photographs a restaurant menu, runs it through Claude vision, classifies each dish Safe / Caution / Avoid (weighted by the user's suspected trigger categories), shows an adaptive can-eat / can't-eat breakdown, and lets the user tap any dish to log it to today.

**Architecture:** Mirror the existing food-photo vision stack end-to-end: a Convex vision `action` (`ai:scanMenu`) → a pure parser (`menuParse.ts`) → a tolerant Codable model (`MenuScan`) → `DayDataSource` / `TodayStore` / `ConvexService` → a new SwiftUI `MenuScanSheet` launched from `RootTabView`'s action fan.

**Tech Stack:** SwiftUI (iOS 17), HavenCore (Swift, swift-testing), Convex (TypeScript) + Anthropic Messages API (Claude Haiku 4.5 vision), vitest.

**Spec:** `docs/superpowers/specs/2026-06-15-menu-scanner-design.md`

**Repo root:** `/Users/willmorphy/.superset/projects/Migraine` (contains `Haven/`, `HavenCore/`, `convex/`). All paths below are relative to repo root unless absolute.

**Conventions you must follow:**
- HavenCore tests use **swift-testing** (`import Testing`, `@Test`, `@Suite`, `#expect`) — NOT XCTest. Run with `swift test` from `HavenCore/`.
- After adding/removing any file under `Haven/Sources`, run `cd Haven && xcodegen generate` (the `.xcodeproj` is generated and gitignored).
- `LoggerKind` is declared in `Haven/Sources/Today/Loggers/SpeedDial.swift`. The `SpeedDial` *view* in that file is dead code (never instantiated); the live action fan is `RootTabView.fanOverlay` driven by `loggerItems`. Do not wire `SpeedDial` the view.
- `Level` enum is `low, mid, high` (no `medium`). `TriggerChip(label:level:reason:)`, `reason` is `String?`.

---

### Task 1: Convex menu parser (`parseMenuAnalysis`)

Pure JSON parser, mirrors `convex/foodParse.ts`. Unit-tested with vitest.

**Files:**
- Create: `convex/menuParse.ts`
- Test: `convex/menuParse.test.ts`

- [ ] **Step 1: Write the failing test**

Create `convex/menuParse.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { parseMenuAnalysis } from "./menuParse";

describe("parseMenuAnalysis", () => {
  it("parses dishes and keeps triggers", () => {
    const text =
      '{"dishes":[{"name":"Margherita Pizza","verdict":"avoid","triggers":["aged cheese","tomato"],"reason":"tyramine and tomato"},{"name":"Garden Salad","verdict":"safe","triggers":[],"reason":""}]}';
    const r = parseMenuAnalysis(text, "Dish");
    expect(r.dishes).toHaveLength(2);
    expect(r.dishes[0].verdict).toBe("avoid");
    expect(r.dishes[0].triggers).toEqual(["aged cheese", "tomato"]);
    expect(r.dishes[1].verdict).toBe("safe");
  });

  it("strips code fences and maps verdict synonyms", () => {
    const text = '```json\n{"dishes":[{"name":"X","verdict":"high"},{"name":"Y","verdict":"warn"}]}\n```';
    const r = parseMenuAnalysis(text, "Dish");
    expect(r.dishes[0].verdict).toBe("avoid");
    expect(r.dishes[1].verdict).toBe("caution");
  });

  it("defaults unknown verdict to caution and drops empty names", () => {
    const text = '{"dishes":[{"name":"","verdict":"safe"},{"name":"Z","verdict":"???"}]}';
    const r = parseMenuAnalysis(text, "Dish");
    expect(r.dishes).toHaveLength(1);
    expect(r.dishes[0].name).toBe("Z");
    expect(r.dishes[0].verdict).toBe("caution");
  });

  it("caps dishes at 30 and clamps long fields", () => {
    const many = Array.from({ length: 40 }, (_, i) => ({ name: "D" + i, verdict: "safe" }));
    const r = parseMenuAnalysis(JSON.stringify({ dishes: many }), "Dish");
    expect(r.dishes).toHaveLength(30);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run convex/menuParse.test.ts`
Expected: FAIL — cannot resolve `./menuParse` (module not found).

- [ ] **Step 3: Write minimal implementation**

Create `convex/menuParse.ts`:

```ts
const VERDICTS: Record<string, "safe" | "caution" | "avoid"> = {
  safe: "safe", ok: "safe", good: "safe", low: "safe",
  caution: "caution", warn: "caution", warning: "caution", mid: "caution", medium: "caution", maybe: "caution",
  avoid: "avoid", high: "avoid", danger: "avoid", bad: "avoid",
};

export function parseMenuAnalysis(text: string, fallbackName: string) {
  const clean = text.replace(/```json|```/g, "").trim();
  const parsed = JSON.parse(clean);
  const raw = Array.isArray(parsed.dishes) ? parsed.dishes : [];
  const dishes = raw
    .slice(0, 30)
    .map((d: any) => {
      const triggers = (Array.isArray(d.triggers) ? d.triggers : [])
        .map((x: any) => String(x))
        .filter((s: string) => s.length > 0);
      return {
        name: String(d.name ?? fallbackName).slice(0, 48),
        verdict: VERDICTS[String(d.verdict).toLowerCase()] ?? "caution",
        triggers,
        reason: String(d.reason ?? "").slice(0, 60),
      };
    })
    .filter((d: any) => d.name.length > 0);
  return { dishes };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run convex/menuParse.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add convex/menuParse.ts convex/menuParse.test.ts
git commit -m "feat(convex): menu analysis JSON parser"
```

---

### Task 2: Convex `scanMenu` vision action

Adds the vision action to `convex/ai.ts`, reusing `callClaude`. Requires making `callClaude` accept a `maxTokens` (menus produce long output).

**Files:**
- Modify: `convex/ai.ts` (add import, parameterize `callClaude`, add `scanMenu`)

- [ ] **Step 1: Parameterize `callClaude` and import the parser**

In `convex/ai.ts`, add to the imports at the top (after the existing `import { parseAnalysis } from "./foodParse";`):

```ts
import { parseMenuAnalysis } from "./menuParse";
```

Change the `callClaude` signature from:

```ts
async function callClaude(content: any): Promise<string> {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not configured");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({ model: "claude-haiku-4-5-20251001", max_tokens: 512, messages: [{ role: "user", content }] }),
  });
```

to:

```ts
async function callClaude(content: any, maxTokens = 512): Promise<string> {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not configured");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({ model: "claude-haiku-4-5-20251001", max_tokens: maxTokens, messages: [{ role: "user", content }] }),
  });
```

(The two existing callers — `analyzeFood` and `analyzeFoodImage` — keep the default 512 and need no change.)

- [ ] **Step 2: Add the `scanMenu` action**

Append to the end of `convex/ai.ts`:

```ts
export const scanMenu = action({
  args: { imageBase64: v.string(), suspected: v.optional(v.array(v.string())) },
  handler: async (_ctx, { imageBase64, suspected }) => {
    const focus =
      suspected && suspected.length > 0
        ? `The user especially suspects these trigger categories: ${suspected.join(", ")}. Weight those higher when in doubt.\n`
        : ``;
    const text =
      `This is a photo of a restaurant menu. List each distinct dish you can read. ` +
      `For each dish, classify it for a migraine sufferer as safe, caution, or avoid using these triggers: ${TRIGGERS_GUIDE}\n` +
      focus +
      `Reply with ONLY minified JSON, no markdown, exactly this shape:\n` +
      `{"dishes":[{"name":"dish name","verdict":"safe|caution|avoid","triggers":["aged cheese"],"reason":"short reason under 8 words"}]}\n` +
      `If a dish has no likely trigger use verdict "safe" and triggers [].`;
    const content = [
      { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
      { type: "text", text },
    ];
    return parseMenuAnalysis(await callClaude(content, 1500), "Dish");
  },
});
```

- [ ] **Step 3: Typecheck / push to dev**

Run: `npx convex dev --once`
Expected: Pushes functions to the dev deployment (`cool-anteater-665`) with no TypeScript errors. The new `ai:scanMenu` appears in the generated API. (If it prompts and aborts non-interactively, that still surfaces type errors first; a clean run prints "Convex functions ready".)

- [ ] **Step 4: Deploy to prod**

Run: `npx convex deploy --yes`
Expected: Pushes schema + functions to prod (`focused-turtle-754`). The prod `ANTHROPIC_API_KEY` env var is already set from the food-vision work, so `scanMenu` is live.

- [ ] **Step 5: Commit**

```bash
git add convex/ai.ts
git commit -m "feat(convex): scanMenu vision action"
```

---

### Task 3: `MenuScan` model in HavenCore

The tolerant Codable model plus the two pure helpers (`grouped()` adaptive lead, `asTriggerChips()`).

**Files:**
- Create: `HavenCore/Sources/HavenCore/MenuScan.swift`
- Test: `HavenCore/Tests/HavenCoreTests/MenuScanTests.swift`

- [ ] **Step 1: Write the failing test**

Create `HavenCore/Tests/HavenCoreTests/MenuScanTests.swift`:

```swift
import Testing
import Foundation
@testable import HavenCore

@Suite struct MenuScanTests {
    @Test func decodesDishesTolerantly() throws {
        let json = """
        {"dishes":[
          {"name":"Pizza","verdict":"avoid","triggers":["aged cheese"],"reason":"tyramine"},
          {"name":"Salad","verdict":"safe"}
        ]}
        """
        let scan = try JSONDecoder().decode(MenuScan.self, from: Data(json.utf8))
        #expect(scan.dishes.count == 2)
        #expect(scan.dishes[0].verdict == .avoid)
        #expect(scan.dishes[0].triggers == ["aged cheese"])
        #expect(scan.dishes[1].verdict == .safe)
        #expect(scan.dishes[1].triggers.isEmpty)   // missing array -> []
        #expect(scan.dishes[1].reason.isEmpty)      // missing string -> ""
    }

    @Test func unknownVerdictDecodesToCaution() throws {
        let json = #"{"dishes":[{"name":"Mystery","verdict":"weird"}]}"#
        let scan = try JSONDecoder().decode(MenuScan.self, from: Data(json.utf8))
        #expect(scan.dishes[0].verdict == .caution)
    }

    @Test func groupedLeadsWithShorterList() {
        // 3 can-eat (safe/caution), 1 avoid -> lead with the avoid list
        let scan = MenuScan(dishes: [
            d("A", .safe), d("B", .caution), d("C", .safe), d("D", .avoid),
        ])
        let g = scan.grouped()
        #expect(g.canEat.count == 3)
        #expect(g.cantEat.count == 1)
        #expect(g.lead == .cantEat)
    }

    @Test func groupedLeadsWithCanEatWhenMoreAvoids() {
        let scan = MenuScan(dishes: [d("A", .safe), d("B", .avoid), d("C", .avoid)])
        #expect(scan.grouped().lead == .canEat)
    }

    @Test func groupedTieLeadsWithCanEat() {
        let scan = MenuScan(dishes: [d("A", .safe), d("B", .avoid)])
        #expect(scan.grouped().lead == .canEat)
    }

    @Test func asTriggerChipsMapsVerdictToLevel() {
        #expect(d("A", .avoid, ["cheese"]).asTriggerChips().first?.level == .high)
        #expect(d("A", .caution, ["nuts"]).asTriggerChips().first?.level == .mid)
        #expect(d("A", .safe, ["x"]).asTriggerChips().isEmpty)   // safe -> no chips
    }

    private func d(_ name: String, _ v: DishVerdict, _ t: [String] = []) -> MenuDish {
        MenuDish(name: name, verdict: v, triggers: t, reason: "")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd HavenCore && swift test --filter MenuScanTests`
Expected: FAIL — `MenuScan`, `MenuDish`, `DishVerdict` are undefined (compile error).

- [ ] **Step 3: Write minimal implementation**

Create `HavenCore/Sources/HavenCore/MenuScan.swift`:

```swift
import Foundation

public enum DishVerdict: String, Codable, Sendable, Equatable {
    case safe, caution, avoid
    public init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self))?.lowercased() ?? ""
        self = DishVerdict(rawValue: raw) ?? .caution   // unknown -> caution
    }
}

public struct MenuDish: Codable, Sendable, Equatable, Identifiable {
    public let name: String
    public let verdict: DishVerdict
    public let triggers: [String]
    public let reason: String
    public var id: String { name }

    public init(name: String, verdict: DishVerdict, triggers: [String] = [], reason: String = "") {
        self.name = name; self.verdict = verdict; self.triggers = triggers; self.reason = reason
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        verdict = (try? c.decode(DishVerdict.self, forKey: .verdict)) ?? .caution
        triggers = (try? c.decode([String].self, forKey: .triggers)) ?? []
        reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
    }

    /// Maps the dish to trigger chips for logging. Verdict drives the level; safe dishes carry no chips.
    public func asTriggerChips() -> [TriggerChip] {
        let level: Level
        switch verdict {
        case .avoid: level = .high
        case .caution: level = .mid
        case .safe: return []
        }
        return triggers.map { TriggerChip(label: $0, level: level, reason: reason.isEmpty ? nil : reason) }
    }
}

public struct MenuScan: Codable, Sendable, Equatable {
    public let dishes: [MenuDish]
    public init(dishes: [MenuDish]) { self.dishes = dishes }

    public enum Lead: Sendable, Equatable { case canEat, cantEat }

    /// canEat = safe + caution; cantEat = avoid. Lead with the SHORTER list (more actionable); tie -> canEat.
    public func grouped() -> (canEat: [MenuDish], cantEat: [MenuDish], lead: Lead) {
        let canEat = dishes.filter { $0.verdict != .avoid }
        let cantEat = dishes.filter { $0.verdict == .avoid }
        let lead: Lead = cantEat.count < canEat.count ? .cantEat : .canEat
        return (canEat, cantEat, lead)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd HavenCore && swift test --filter MenuScanTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/MenuScan.swift HavenCore/Tests/HavenCoreTests/MenuScanTests.swift
git commit -m "feat(core): MenuScan model with adaptive grouping"
```

---

### Task 4: `scanMenu` on `DayDataSource` + `TodayStore`

Protocol method, `FakeSource` stub, and the store method that derives suspected categories from onboarding answers.

**Files:**
- Modify: `HavenCore/Sources/HavenCore/DayDataSource.swift` (add protocol method)
- Modify: `HavenCore/Sources/HavenCore/TodayStore.swift` (add `scanMenu`)
- Modify: `HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift` (extend `FakeSource`, add tests)

- [ ] **Step 1: Write the failing test**

In `HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift`, first extend `FakeSource` (add these members anywhere inside the `FakeSource` class body, e.g. right after the `analyzeFoodImage` block):

```swift
    var menuScanResult = MenuScan(dishes: [])
    var menuScanShouldThrow = false
    private(set) var lastSuspected: [String]?
    func scanMenu(imageBase64: String, suspected: [String]) async throws -> MenuScan {
        lastSuspected = suspected
        if menuScanShouldThrow { throw NSError(domain: "x", code: 1) }
        return menuScanResult
    }
```

Then add these tests inside `struct TodayStoreTests` (anywhere among the existing `@Test` methods):

```swift
    @Test func scanMenuPassesSuspectedFromAnswersAndReturnsResult() async {
        let source = FakeSource(day: nil)
        source.settings = Settings(theme: "dark", onboarded: true, answers: #"{"triggers":["caffeine","alcohol","unsure"]}"#)
        source.menuScanResult = MenuScan(dishes: [MenuDish(name: "Latte", verdict: .avoid, triggers: ["caffeine"])])
        let store = TodayStore(source: source, today: "2026-06-15")
        let scan = await store.scanMenu(imageBase64: "abc")
        #expect(scan.dishes.first?.name == "Latte")
        #expect(source.lastSuspected == ["caffeine", "alcohol"])   // "unsure" filtered out
    }

    @Test func scanMenuReturnsEmptyOnError() async {
        let source = FakeSource(day: nil)
        source.menuScanShouldThrow = true
        let store = TodayStore(source: source, today: "2026-06-15")
        let scan = await store.scanMenu(imageBase64: "abc")
        #expect(scan.dishes.isEmpty)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd HavenCore && swift test --filter TodayStoreTests`
Expected: FAIL — `FakeSource` does not conform to `DayDataSource` (missing protocol method) AND `store.scanMenu` is undefined.

- [ ] **Step 3a: Add the protocol method**

In `HavenCore/Sources/HavenCore/DayDataSource.swift`, add this line directly after the `analyzeFoodImage` declaration:

```swift
    func scanMenu(imageBase64: String, suspected: [String]) async throws -> MenuScan
```

- [ ] **Step 3b: Add the store method**

In `HavenCore/Sources/HavenCore/TodayStore.swift`, add directly after the `analyzeImage(imageBase64:hint:)` method (before the closing brace of the class):

```swift
    /// Scans a menu photo via the server vision action. Suspected trigger categories come from
    /// onboarding answers (weighting). On any error returns an empty scan (no on-device fallback —
    /// vision is required to read a menu).
    public func scanMenu(imageBase64: String) async -> MenuScan {
        let answers = (try? await source.getSettings())?.answers ?? "{}"
        let suspected = (answersDict(from: answers)["triggers"] ?? []).filter { $0 != "unsure" }
        do { return try await source.scanMenu(imageBase64: imageBase64, suspected: suspected) }
        catch { return MenuScan(dishes: []) }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd HavenCore && swift test --filter TodayStoreTests`
Expected: PASS (existing tests + the 2 new ones).

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/DayDataSource.swift HavenCore/Sources/HavenCore/TodayStore.swift HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift
git commit -m "feat(core): scanMenu on DayDataSource and TodayStore"
```

---

### Task 5: `ConvexService.scanMenu`

Wire the real Convex action into the app's data source. (Not unit-tested — `ConvexService` is the live network adapter; correctness is verified by the build + on-device run.)

**Files:**
- Modify: `Haven/Sources/Services/ConvexService.swift` (add method after `analyzeFoodImage`, lines ~114)

- [ ] **Step 1: Add the method**

In `Haven/Sources/Services/ConvexService.swift`, add directly after the `analyzeFoodImage` method (after the closing brace at ~line 114):

```swift
    func scanMenu(imageBase64: String, suspected: [String]) async throws -> MenuScan {
        var args: [String: ConvexEncodable?] = ["imageBase64": imageBase64]
        if !suspected.isEmpty { args["suspected"] = suspected }
        let result: MenuScan = try await client.action("ai:scanMenu", with: args)
        return result
    }
```

- [ ] **Step 2: Regenerate and build**

Run:
```bash
cd Haven && xcodegen generate && \
xcodebuild -project Haven.xcodeproj -scheme Haven \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. (No new files were added, so `xcodegen generate` is a no-op here but harmless; it's required in Task 7.)

- [ ] **Step 3: Commit**

```bash
git add Haven/Sources/Services/ConvexService.swift
git commit -m "feat(app): ConvexService.scanMenu"
```

---

### Task 6: Add the `.menu` action to the fan

Add the enum case and wire the fan entry + sheet routing. The `MenuScanSheet` view is built in Task 7; this task adds a temporary placeholder so the project compiles, which Task 7 replaces.

**Files:**
- Modify: `Haven/Sources/Today/Loggers/SpeedDial.swift` (add `case menu` to `LoggerKind`)
- Modify: `Haven/Sources/App/RootTabView.swift` (add fan item + sheet routing)

- [ ] **Step 1: Add the enum case**

In `Haven/Sources/Today/Loggers/SpeedDial.swift`, change:

```swift
enum LoggerKind: String, Identifiable { case food, migraine, symptom, factors; var id: String { rawValue } }
```

to:

```swift
enum LoggerKind: String, Identifiable { case food, migraine, symptom, factors, menu; var id: String { rawValue } }
```

- [ ] **Step 2: Add the fan item**

In `Haven/Sources/App/RootTabView.swift`, change `loggerItems` (lines ~72-75) from:

```swift
    private let loggerItems: [(LoggerKind, String, String)] = [
        (.food, "Food", "camera"), (.migraine, "Migraine", "bolt.heart"),
        (.symptom, "Symptom", "eye"), (.factors, "Daily factors", "moon"),
    ]
```

to:

```swift
    private let loggerItems: [(LoggerKind, String, String)] = [
        (.food, "Food", "camera"), (.migraine, "Migraine", "bolt.heart"),
        (.symptom, "Symptom", "eye"), (.factors, "Daily factors", "moon"),
        (.menu, "Scan menu", "doc.text.viewfinder"),
    ]
```

- [ ] **Step 3: Add sheet routing (temporary placeholder body)**

In `Haven/Sources/App/RootTabView.swift`, in the `sheet(for:)` `@ViewBuilder` switch, add a `.menu` case after the `.food` case:

```swift
        case .menu: MenuScanSheet(
            scanMenu: { data in await store.scanMenu(imageBase64: data.base64EncodedString()) },
            onLog: { food in try? await store.saveFood(food) })
```

Then create a minimal placeholder so it compiles now (Task 7 replaces this whole file). Create `Haven/Sources/Today/Loggers/MenuScanSheet.swift`:

```swift
import SwiftUI
import HavenCore

struct MenuScanSheet: View {
    let scanMenu: (Data) async -> MenuScan
    let onLog: (FoodEntry) async -> Void
    var body: some View { Text("Menu scanner") }
}
```

- [ ] **Step 4: Regenerate and build**

Run:
```bash
cd Haven && xcodegen generate && \
xcodebuild -project Haven.xcodeproj -scheme Haven \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. The switch is now exhaustive over all five `LoggerKind` cases.

- [ ] **Step 5: Commit**

```bash
git add Haven/Sources/Today/Loggers/SpeedDial.swift Haven/Sources/App/RootTabView.swift Haven/Sources/Today/Loggers/MenuScanSheet.swift
git commit -m "feat(app): wire Scan menu into the action fan"
```

---

### Task 7: `MenuScanSheet` UI

Replace the placeholder with the full sheet: photo picker → scan → adaptive results → tap-to-log. Patterns mirror `FoodCaptureSheet.swift`.

**Files:**
- Modify (replace whole file): `Haven/Sources/Today/Loggers/MenuScanSheet.swift`

**Reference patterns (already in the codebase):**
- `SheetHeader(title:subtitle:)`, `Segmented`, `LevelDot(level:)` — defined alongside the other loggers (used by `FoodCaptureSheet.swift`).
- `ImageScaler.downscaledJPEG(_:)` — `Haven/Sources/Today/Loggers/ImageScaler.swift`.
- Design tokens: `theme.bg/surface/ink/inkSoft/inkFaint/ctaBg/ctaInk/accent`, `Spacing.s1…s7`, `Radius.md/lg`, `.havenText(.sectionHead/.body/.meta/.eyebrow, color:)`.

- [ ] **Step 1: Replace the file**

Write `Haven/Sources/Today/Loggers/MenuScanSheet.swift`:

```swift
import SwiftUI
import PhotosUI
import HavenDesignSystem
import HavenCore

struct MenuScanSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let scanMenu: (Data) async -> MenuScan
    let onLog: (FoodEntry) async -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var busy = false
    @State private var result: MenuScan?
    @State private var loggedDishes: Set<String> = []   // dish.id of dishes already logged

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    SheetHeader(title: "Scan menu", subtitle: "Photo a menu — see what's safe")
                    if let result {
                        resultView(result)
                    } else {
                        captureView
                    }
                }
                .padding(Spacing.s6)
            }
        }
    }

    private var captureView: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack { Image(systemName: "doc.text.viewfinder"); Text("Add a menu photo").havenText(.meta, color: theme.ink) }
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s7)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    .foregroundStyle(theme.inkSoft)
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let raw = try? await item?.loadTransferable(type: Data.self) {
                        imageData = ImageScaler.downscaledJPEG(raw)
                    }
                }
            }
            if imageData != nil { Text("Photo attached").havenText(.meta, color: theme.inkSoft) }
            Button {
                guard let data = imageData else { return }
                busy = true
                Task { result = await scanMenu(data); busy = false }
            } label: {
                HStack { if busy { ProgressView() }; Text(busy ? "Scanning" : "Scan menu").havenText(.sectionHead, color: theme.ctaInk) }
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                    .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            }
            .disabled(busy || imageData == nil)
            .accessibilityIdentifier("menu-scan")
            Text("Assessments are informational and may be wrong.").havenText(.meta, color: theme.inkFaint)
        }
    }

    @ViewBuilder private func resultView(_ scan: MenuScan) -> some View {
        if scan.dishes.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Couldn't read that menu").havenText(.sectionHead, color: theme.ink)
                Text("Try a clearer, well-lit photo of the menu text.").havenText(.body, color: theme.inkSoft)
                redoButton
            }
        } else {
            let g = scan.grouped()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("\(scan.dishes.count) dishes · \(g.canEat.count) you can eat")
                    .havenText(.meta, color: theme.inkSoft)
                if g.lead == .cantEat {
                    section("BEST TO AVOID", g.cantEat)
                    section("YOU CAN EAT", g.canEat)
                } else {
                    section("YOU CAN EAT", g.canEat)
                    section("BEST TO AVOID", g.cantEat)
                }
                redoButton
                Text("Tap a dish to log it. Assessments are informational and may be wrong.")
                    .havenText(.meta, color: theme.inkFaint)
            }
        }
    }

    @ViewBuilder private func section(_ title: String, _ dishes: [MenuDish]) -> some View {
        if !dishes.isEmpty {
            Text(title).havenText(.eyebrow, color: theme.inkFaint)
            ForEach(Array(dishes.enumerated()), id: \.element.id) { index, dish in
                Button {
                    Task {
                        await onLog(FoodEntry(name: dish.name, time: TodayStore.nowHM(),
                                              triggers: dish.asTriggerChips(), note: "From menu scan", imageId: nil))
                        loggedDishes.insert(dish.id)
                    }
                } label: { dishRow(dish) }
                .accessibilityIdentifier("menu-dish-\(index)")
            }
        }
    }

    private func dishRow(_ dish: MenuDish) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Circle().fill(color(for: dish.verdict)).frame(width: 10, height: 10).padding(.top, Spacing.s2)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                HStack {
                    Text(dish.name).havenText(.body, color: theme.ink)
                    Spacer()
                    if loggedDishes.contains(dish.id) {
                        Label("Logged", systemImage: "checkmark").havenText(.meta, color: theme.inkSoft)
                    }
                }
                if !dish.reason.isEmpty { Text(dish.reason).havenText(.meta, color: theme.inkFaint) }
            }
        }
        .padding(Spacing.s4).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private func color(for verdict: DishVerdict) -> Color {
        switch verdict {
        case .safe: return .green
        case .caution: return .orange
        case .avoid: return .red
        }
    }

    private var redoButton: some View {
        Button { result = nil; imageData = nil; photoItem = nil; loggedDishes = [] } label: {
            Text("Scan another").havenText(.meta, color: theme.inkSoft)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
        }
    }
}
```

- [ ] **Step 2: Regenerate and build**

Run:
```bash
cd Haven && xcodegen generate && \
xcodebuild -project Haven.xcodeproj -scheme Haven \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify in the simulator (manual / Maestro)**

Boot the simulator, run the app, open the action fan (the `+` button), tap "Scan menu", attach a photo from the photo library, tap "Scan menu". Confirm:
- A results list appears with colored dots and reasons.
- The shorter of the two lists renders first under the right header.
- Tapping a dish shows "Logged" and the dish appears in Today's ledger.

(If the simulator photo library is empty, drag an image onto the simulator first, or use a menu screenshot.)

- [ ] **Step 4: Commit**

```bash
git add Haven/Sources/Today/Loggers/MenuScanSheet.swift
git commit -m "feat(app): MenuScanSheet UI with adaptive results and tap-to-log"
```

---

## Final verification (after all tasks)

- [ ] `cd HavenCore && swift test` — all HavenCore tests pass.
- [ ] `npx vitest run` — all convex tests pass.
- [ ] `cd Haven && xcodegen generate && xcodebuild -project Haven.xcodeproj -scheme Haven -destination 'platform=iOS Simulator,name=iPhone 16' build` — `** BUILD SUCCEEDED **`.
- [ ] Manual simulator pass of the scan→results→log flow (Task 7 Step 3).
- [ ] Backend deployed to prod (`npx convex deploy --yes`).
