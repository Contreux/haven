# Food Photo Vision Analysis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Analyze the meal photo itself with Claude Haiku vision, extracting detected items + migraine triggers.

**Architecture:** A pure parse helper + a new vision Convex action; `AnalyzedFood` gains an `items` list (tolerant decode); the `DayDataSource` protocol grows with both conformers updated in lockstep; the capture sheet downscales the photo, sends it base64, and shows an items section. On-device `TriggerEngine` stays the text-only fallback.

**Tech Stack:** Swift 6 / SwiftUI, Convex (TS) + convex-test/vitest, Anthropic Messages API (image content block), Claude Haiku 4.5.

**Spec:** `docs/superpowers/specs/2026-06-15-food-photo-vision-design.md`

---

### Task 1: AnalyzedFood gains `items` (tolerant decode)

**Files:** Modify `HavenCore/Sources/HavenCore/TriggerEngine.swift`; Test `HavenCore/Tests/HavenCoreTests/AnalyzedFoodTests.swift`.

- [ ] **Step 1: Failing test** — create `HavenCore/Tests/HavenCoreTests/AnalyzedFoodTests.swift`:

```swift
import Testing
import Foundation
@testable import HavenCore

@Suite struct AnalyzedFoodTests {
    @Test func decodesWithItems() throws {
        let json = #"{"label":"Burger meal","items":["Cheeseburger","Fries"],"triggers":[],"note":"ok"}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(AnalyzedFood.self, from: json)
        #expect(a.items == ["Cheeseburger", "Fries"])
    }
    @Test func toleratesMissingItems() throws {
        let json = #"{"label":"x","triggers":[],"note":""}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(AnalyzedFood.self, from: json)
        #expect(a.items == [])
    }
    @Test func triggerEngineReturnsEmptyItems() {
        #expect(TriggerEngine.analyze("red wine and brie").items == [])
    }
}
```

- [ ] **Step 2: Run, confirm FAIL** — `cd HavenCore && swift test --filter AnalyzedFoodTests 2>&1 | grep -v clocale` (no `items` member).

- [ ] **Step 3: Implement** — replace the `AnalyzedFood` struct at the top of `HavenCore/Sources/HavenCore/TriggerEngine.swift` with:

```swift
public struct AnalyzedFood: Codable, Sendable, Equatable {
    public let label: String
    public let items: [String]
    public let triggers: [TriggerChip]
    public let note: String
    public init(label: String, items: [String] = [], triggers: [TriggerChip], note: String) {
        self.label = label; self.items = items; self.triggers = triggers; self.note = note
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        items = (try? c.decode([String].self, forKey: .items)) ?? []
        triggers = try c.decode([TriggerChip].self, forKey: .triggers)
        note = try c.decode(String.self, forKey: .note)
    }
}
```

The existing `TriggerEngine.analyze` return call `AnalyzedFood(label:..., triggers:..., note:...)` still compiles because `items` defaults to `[]`. Leave it as-is.

- [ ] **Step 4: Run, confirm PASS** — `cd HavenCore && swift test --filter AnalyzedFoodTests 2>&1 | grep -v clocale` (3 pass), then full suite `swift test 2>&1 | grep -vE "clocale|pristine" | tail -2`.

- [ ] **Step 5: Commit**

```bash
git add HavenCore/Sources/HavenCore/TriggerEngine.swift HavenCore/Tests/HavenCoreTests/AnalyzedFoodTests.swift
git commit -m "feat(core): AnalyzedFood gains items list with tolerant decode"
```

---

### Task 2: Convex — pure parse helper + vision action

**Files:** Create `convex/foodParse.ts`; Modify `convex/ai.ts`; Test `convex/foodParse.test.ts`, `convex/ai.test.ts`.

- [ ] **Step 1: Failing tests** — create `convex/foodParse.test.ts`:

```typescript
import { expect, test } from "vitest";
import { parseAnalysis } from "./foodParse";

test("parses itemized JSON with triggers", () => {
  const r = parseAnalysis('{"label":"Burger","items":["Cheeseburger","Fries"],"triggers":[{"name":"Aged cheese","level":"high","reason":"tyramine"}],"note":"ok"}', "fallback");
  expect(r.items).toEqual(["Cheeseburger", "Fries"]);
  expect(r.triggers[0]).toEqual({ label: "Aged cheese", level: "high", reason: "tyramine" });
  expect(r.label).toBe("Burger");
});
test("strips markdown fences and normalizes medium->mid", () => {
  const r = parseAnalysis('```json\n{"label":"x","items":[],"triggers":[{"name":"Caffeine","level":"medium","reason":"r"}],"note":""}\n```', "fb");
  expect(r.triggers[0].level).toBe("mid");
});
test("missing items -> [] and empty triggers ok", () => {
  const r = parseAnalysis('{"label":"x","triggers":[],"note":""}', "fb");
  expect(r.items).toEqual([]);
  expect(r.triggers).toEqual([]);
});
test("falls back to provided label when absent", () => {
  const r = parseAnalysis('{"triggers":[],"note":""}', "My hint");
  expect(r.label).toBe("My hint");
});
```

Append to `convex/ai.test.ts`:

```typescript
test("analyzeFoodImage throws when no API key is configured", async () => {
  const t = convexTest(schema, modules);
  await expect(
    t.action(api.ai.analyzeFoodImage, { imageBase64: "QUJD" }),
  ).rejects.toThrow();
});
```

- [ ] **Step 2: Run, confirm FAIL** — `npx vitest run convex/foodParse.test.ts convex/ai.test.ts 2>&1 | tail -15`.

- [ ] **Step 3: Create `convex/foodParse.ts`** (pure, no "use node"):

```typescript
export const LEVELS: Record<string, "low" | "mid" | "high"> = {
  high: "high", medium: "mid", mid: "mid", low: "low",
};

export function parseAnalysis(text: string, fallbackLabel: string) {
  const clean = text.replace(/```json|```/g, "").trim();
  const parsed = JSON.parse(clean); // throws on bad shape → caller's action throws → client falls back
  const triggers = (Array.isArray(parsed.triggers) ? parsed.triggers : []).map((t: any) => ({
    label: String(t.name ?? t.label ?? "Trigger"),
    level: LEVELS[String(t.level).toLowerCase()] ?? "low",
    reason: String(t.reason ?? ""),
  }));
  const items = (Array.isArray(parsed.items) ? parsed.items : [])
    .map((x: any) => String(x)).filter((s: string) => s.length > 0);
  return {
    label: String(parsed.label ?? fallbackLabel).slice(0, 42),
    items,
    triggers,
    note: String(parsed.note ?? ""),
  };
}
```

- [ ] **Step 4: Refactor `convex/ai.ts`** — replace the file's body so the text action reuses `parseAnalysis` and add the vision action:

```typescript
"use node";
import { action } from "./_generated/server";
import { v } from "convex/values";
import { parseAnalysis } from "./foodParse";

const TRIGGERS_GUIDE =
  "Common migraine triggers: aged cheese (tyramine), cured/processed meats (nitrates), chocolate, caffeine, alcohol (esp. red wine), MSG, aspartame, citrus, fermented foods, nuts, soy sauce, tomatoes.";

const JSON_SHAPE =
  `Reply with ONLY valid minified JSON, no markdown, exactly this shape:\n` +
  `{"label":"short meal name","items":["each distinct food or drink"],"triggers":[{"name":"Aged cheese","level":"high","reason":"short reason under 8 words"}],"note":"one short calm sentence"}\n` +
  `Rank triggers high→low. level is "high","medium" or "low". If none, use [].`;

async function callClaude(content: any): Promise<string> {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not configured");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({ model: "claude-haiku-4-5-20251001", max_tokens: 512, messages: [{ role: "user", content }] }),
  });
  if (!res.ok) throw new Error(`Anthropic error ${res.status}`);
  const data = await res.json();
  return data?.content?.[0]?.text ?? "";
}

export const analyzeFood = action({
  args: { description: v.string() },
  handler: async (_ctx, { description }) => {
    const prompt = `You are a migraine dietary-trigger assistant. A user ate/drank: "${description}".\n` +
      `Identify likely migraine food triggers present. ${TRIGGERS_GUIDE}\n${JSON_SHAPE}`;
    return parseAnalysis(await callClaude(prompt), description);
  },
});

export const analyzeFoodImage = action({
  args: { imageBase64: v.string(), hint: v.optional(v.string()) },
  handler: async (_ctx, { imageBase64, hint }) => {
    const text = `You are a migraine dietary-trigger assistant analyzing a PHOTO of food/drink.\n` +
      `Identify each distinct food or drink item visible, then likely migraine triggers present. ${TRIGGERS_GUIDE}\n` +
      (hint && hint.length > 0 ? `The user adds: "${hint}".\n` : ``) +
      JSON_SHAPE;
    const content = [
      { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
      { type: "text", text },
    ];
    return parseAnalysis(await callClaude(content), hint && hint.length > 0 ? hint : "Meal photo");
  },
});
```

- [ ] **Step 5: Run, confirm PASS** — `npx vitest run convex/foodParse.test.ts convex/ai.test.ts 2>&1 | tail -8`.

- [ ] **Step 6: Typecheck against dev** — `npx convex dev --once 2>&1 | tail -5` (expect "Convex functions ready!", no TS errors).

- [ ] **Step 7: Commit**

```bash
git add convex/foodParse.ts convex/ai.ts convex/foodParse.test.ts convex/ai.test.ts
git commit -m "feat(convex): parseAnalysis helper + analyzeFoodImage vision action"
```

---

### Task 3: Grow DayDataSource (image path) + ConvexService + FakeSource + TodayStore

**Files:** Modify `HavenCore/Sources/HavenCore/DayDataSource.swift`; `HavenCore/Sources/HavenCore/TodayStore.swift`; `Haven/Sources/Services/ConvexService.swift`; `HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift`.

- [ ] **Step 1: Add to the protocol** — in `DayDataSource.swift`, after `analyzeFood`:

```swift
    func analyzeFoodImage(imageBase64: String, hint: String) async throws -> AnalyzedFood
```

- [ ] **Step 2: Confirm build breaks** — `cd HavenCore && swift test 2>&1 | grep -vE "clocale|pristine" | grep -iE "does not conform|error" | head` (FakeSource missing method).

- [ ] **Step 3: Stub on FakeSource** — in `TodayStoreTests.swift`, after the `analyzeFood` stub, add (return a deterministic value for assertions):

```swift
    var imageAnalysis = AnalyzedFood(label: "Photo meal", items: ["Item"], triggers: [], note: "")
    func analyzeFoodImage(imageBase64: String, hint: String) async throws -> AnalyzedFood { imageAnalysis }
```

(If `FakeSource`'s existing `analyzeFood` stub throws to force fallback, mirror its style but this one should return `imageAnalysis` so a success-path test is possible. If a test relies on fallback, it can set behavior accordingly — do not change existing tests unless they fail.)

- [ ] **Step 4: Add the store method** — in `TodayStore.swift`, after `analyze(_:)`:

```swift
    /// Two-tier: try the server vision action; on any error fall back to the on-device engine on the hint.
    public func analyzeImage(imageBase64: String, hint: String) async -> AnalyzedFood {
        do { return try await source.analyzeFoodImage(imageBase64: imageBase64, hint: hint) }
        catch { return TriggerEngine.analyze(hint) }
    }
```

- [ ] **Step 5: Run HavenCore tests** — `cd HavenCore && swift test 2>&1 | grep -vE "clocale|pristine" | tail -2` (all pass).

- [ ] **Step 6: Implement on ConvexService** — in `ConvexService.swift`, after `analyzeFood`:

```swift
    func analyzeFoodImage(imageBase64: String, hint: String) async throws -> AnalyzedFood {
        var args: [String: ConvexEncodable?] = ["imageBase64": imageBase64]
        if !hint.isEmpty { args["hint"] = hint }
        let result: AnalyzedFood = try await client.action("ai:analyzeFoodImage", with: args)
        return result
    }
```

- [ ] **Step 7: Build the app** — `cd Haven && xcodebuild -project Haven.xcodeproj -scheme Haven -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/haven-dd build 2>&1 | grep -iE "BUILD SUCCEEDED|BUILD FAILED|error:" | head` (SUCCEEDED).

- [ ] **Step 8: Commit**

```bash
git add HavenCore/Sources/HavenCore/DayDataSource.swift HavenCore/Sources/HavenCore/TodayStore.swift Haven/Sources/Services/ConvexService.swift HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift
git commit -m "feat: analyzeFoodImage on DayDataSource/ConvexService + TodayStore.analyzeImage"
```

---

### Task 4: Image downscale util + capture-sheet image path + itemized UI

**Files:** Create `Haven/Sources/Today/Loggers/ImageScaler.swift`; Modify `Haven/Sources/Today/Loggers/FoodCaptureSheet.swift`; `Haven/Sources/App/RootTabView.swift`.

- [ ] **Step 1: Create `ImageScaler.swift`**:

```swift
import UIKit

enum ImageScaler {
    /// Downscale to maxDimension and JPEG-compress. Returns original on failure.
    static func downscaledJPEG(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.6) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}
```

- [ ] **Step 2: Add the image analyze closure to `FoodCaptureSheet`** — change the stored closures (lines ~9-10) to add:

```swift
    let analyzeImage: (Data, String) async -> AnalyzedFood
```

In the photo picker `onChange` (currently sets `imageData`), downscale on load:

```swift
                .onChange(of: photoItem) { _, item in
                    Task {
                        if let raw = try? await item?.loadTransferable(type: Data.self) {
                            imageData = ImageScaler.downscaledJPEG(raw)
                        }
                    }
                }
```

Update the Analyze button action to branch on photo presence:

```swift
            Button {
                busy = true
                Task {
                    if mode == .photo, let data = imageData {
                        result = await analyzeImage(data, desc)
                    } else {
                        let text = desc.isEmpty ? "the meal in the photo" : desc
                        result = await analyze(text)
                    }
                    busy = false
                }
            } label: { /* unchanged */ }
```

- [ ] **Step 3: Add the items section to `resultView`** — insert above the "TRIGGERS DETECTED" block:

```swift
            if !r.items.isEmpty {
                Text("ITEMS DETECTED").havenText(.eyebrow, color: theme.inkFaint)
                ForEach(r.items, id: \.self) { item in
                    HStack(spacing: Spacing.s3) {
                        Image(systemName: "fork.knife").foregroundStyle(theme.inkSoft)
                        Text(item).havenText(.body, color: theme.ink)
                    }
                    .padding(.vertical, Spacing.s1)
                }
            }
```

- [ ] **Step 4: Provide the closure in `RootTabView`** — where `FoodCaptureSheet(...)` is constructed (in `sheet(for:)`), add the `analyzeImage` argument:

```swift
        case .food: FoodCaptureSheet(
            analyze: { await store.analyze($0) },
            analyzeImage: { data, hint in await store.analyzeImage(imageBase64: data.base64EncodedString(), hint: hint) },
            onSave: { food, imageData in await saveFood(food, imageData) })
```

(Read the current `FoodCaptureSheet(...)` call site and match argument order/labels; only add `analyzeImage`.)

- [ ] **Step 5: Build + screenshot** — build (command as Task 3 Step 7); then:

```bash
APP=$(find /tmp/haven-dd -name Haven.app -type d | head -1)
xcrun simctl install booted "$APP"; xcrun simctl launch booted app.haven.Haven; sleep 3
xcrun simctl io booted screenshot /tmp/food-vision.png
```
Expected: BUILD SUCCEEDED; the food sheet builds. (Live photo analysis needs a key on the deployment; confirm the describe path still works in the sheet.)

- [ ] **Step 6: Commit**

```bash
git add Haven/Sources/Today/Loggers/ImageScaler.swift Haven/Sources/Today/Loggers/FoodCaptureSheet.swift Haven/Sources/App/RootTabView.swift
git commit -m "feat(app): photo downscale + vision analyze path + itemized results"
```

---

### Task 5: Full regression

- [ ] **Step 1:** `cd HavenCore && swift test 2>&1 | grep -vE "clocale|pristine" | grep "Test run" | tail -1`
- [ ] **Step 2:** `npx vitest run 2>&1 | grep -E "Test Files|Tests " | tail -2`
- [ ] **Step 3:** App build SUCCEEDED (command as above).
- [ ] **Step 4:** Run the existing describe-path Maestro flow if one exists for food; otherwise confirm `Haven/maestro/profile.yaml` still green to ensure no regressions: `~/.maestro/bin/maestro test Haven/maestro/profile.yaml 2>&1 | tail -3`.

---

## Self-Review

**Spec coverage:** items model (T1), pure parse + vision action (T2), protocol/service/store growth in lockstep (T3), downscale + capture path + itemized UI (T4), regression (T5). Fallback preserved in `TodayStore.analyzeImage`. Tolerant decode in T1.

**Type consistency:** `AnalyzedFood(label:items:triggers:note:)`, `parseAnalysis(text, fallbackLabel)`, `analyzeFoodImage(imageBase64:hint:)` (Swift) ↔ `ai:analyzeFoodImage {imageBase64, hint?}` (Convex), `analyzeImage(imageBase64:hint:)` (store) used consistently.

**Check-then-adjust (not placeholders):** T3 Step 3 and T4 Step 4 say to match the existing FakeSource stub style / `FoodCaptureSheet` call-site arg order — explicit verify steps against real code.
