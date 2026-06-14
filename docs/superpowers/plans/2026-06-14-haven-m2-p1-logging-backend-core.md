# Haven M2 · Plan 1 — Logging Backend + Core Logic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the backend + headless core for logging — Convex mutations (migraine/symptoms/food + file storage), the `analyzeFood` LLM action, and the HavenCore additions (extended models, the on-device `TriggerEngine`, and `TodayStore` write/analyze methods) — all test-covered, so M2-P2's logger UI plugs straight in.

**Architecture:** Additive Convex schema changes (optional fields keep M1 data valid) + new mutations following the existing upsert pattern + an `analyzeFood` action that calls Claude and degrades to throwing (client falls back). HavenCore gains a pure `TriggerEngine` (keyword rules), extended `Codable` models, an extended `DayDataSource` protocol, and `TodayStore` methods including the two-tier `analyze`. Everything is covered by `convex-test` (backend) and `swift test` (core).

**Tech Stack:** Convex (TS) · convex-test/Vitest · Swift 6 / Swift Testing · Anthropic API (Claude Haiku 4.5).

**Reference:** spec `docs/superpowers/specs/2026-06-14-haven-m2-logging-design.md`; existing `convex/{schema,days,seed}.ts`, `HavenCore/Sources/HavenCore/{Models,TodayStore,DayDataSource}.swift`.

---

## Scope & dependencies
- **Depends on:** M1 (merged). Convex deployment live (`cool-anteater-665`), `_generated` uses `anyApi`.
- **Produces:** logging backend + core layer + tests. No UI (that's M2-P2).
- **Out of scope:** the sheets, speed-dial, ConvexService wiring (M2-P2).

## Data contract (additive — must not break M1)
- `TriggerChip`: `{ label: String, level: low|mid|high, reason?: String }`
- `FoodEntry`: `{ name, time, triggers[], note?: String, imageId?: String }`
- `analyzeFood` action returns **already-normalized** to our shape: `{ label: String, triggers: [{label, level(low|mid|high), reason}], note: String }` (the action maps the LLM's `name`→`label` and `medium`→`mid`).

---

## Task 1: Extend schema (additive)

**Files:**
- Modify: `convex/schema.ts`
- Test: `convex/schema.test.ts` (extend)

- [ ] **Step 1: Add a failing test** (append to `convex/schema.test.ts`)

```typescript
test("food entry accepts optional note and imageId; trigger accepts reason", async () => {
  const t = convexTest(schema, modules);
  const id = await t.run(async (ctx) =>
    ctx.db.insert("days", {
      userId: "dev-1", date: "2026-06-20", symptoms: [],
      foods: [{
        name: "Red wine", time: "20:00", note: "Glass with dinner",
        triggers: [{ label: "Alcohol", level: "high", reason: "Vasodilator" }],
      }],
    }),
  );
  const doc = await t.run(async (ctx) => ctx.db.get(id));
  expect(doc?.foods[0].note).toBe("Glass with dinner");
  expect(doc?.foods[0].triggers[0].reason).toBe("Vasodilator");
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/schema.test.ts`
Expected: FAIL — `note`/`reason` rejected by the validator.

- [ ] **Step 3: Edit `convex/schema.ts`** — change the `triggerChip` and `foodEntry` validators to:

```typescript
const triggerChip = v.object({
  label: v.string(),
  level: level,
  reason: v.optional(v.string()),
});

const foodEntry = v.object({
  name: v.string(),
  time: v.string(), // "HH:mm"
  triggers: v.array(triggerChip),
  note: v.optional(v.string()),
  imageId: v.optional(v.id("_storage")),
});
```
(Leave `days`/`settings` tables otherwise unchanged.)

- [ ] **Step 4: Run to verify it passes**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/schema.test.ts`
Expected: PASS (both schema tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add convex/schema.ts convex/schema.test.ts
git commit -m "feat: extend schema with food note/imageId and trigger reason"
```

---

## Task 2: Migraine mutations

**Files:**
- Modify: `convex/days.ts`
- Test: `convex/days.test.ts` (extend)

- [ ] **Step 1: Add failing tests**

```typescript
test("setMigraine upserts the day's migraine", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.days.setMigraine, {
    userId: "dev-1", date: "2026-06-14",
    migraine: { had: true, severity: "Moderate", time: "15:10", notes: "left eye" },
  });
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day?.migraine?.had).toBe(true);
  expect(day?.migraine?.severity).toBe("Moderate");
});

test("removeMigraine clears it", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.days.setMigraine, {
    userId: "dev-1", date: "2026-06-14",
    migraine: { had: true, severity: "Mild", time: "10:00", notes: "" },
  });
  await t.mutation(api.days.removeMigraine, { userId: "dev-1", date: "2026-06-14" });
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day?.migraine?.had ?? false).toBe(false);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/days.test.ts`
Expected: FAIL — `api.days.setMigraine` undefined.

- [ ] **Step 3: Append to `convex/days.ts`** (a shared upsert helper + the two mutations)

```typescript
const migraineArg = v.object({
  had: v.boolean(),
  severity: v.string(),
  time: v.string(),
  notes: v.string(),
});

// Find-or-create the day row for (userId, date); returns the existing doc or null.
async function findDay(ctx: any, userId: string, date: string) {
  return await ctx.db
    .query("days")
    .withIndex("by_user_date", (q: any) => q.eq("userId", userId).eq("date", date))
    .unique();
}

export const setMigraine = mutation({
  args: { userId: v.string(), date: v.string(), migraine: migraineArg },
  handler: async (ctx, { userId, date, migraine }) => {
    const existing = await findDay(ctx, userId, date);
    if (existing) {
      await ctx.db.patch(existing._id, { migraine });
      return existing._id;
    }
    return await ctx.db.insert("days", { userId, date, migraine, symptoms: [], foods: [] });
  },
});

export const removeMigraine = mutation({
  args: { userId: v.string(), date: v.string() },
  handler: async (ctx, { userId, date }) => {
    const existing = await findDay(ctx, userId, date);
    if (existing) await ctx.db.patch(existing._id, { migraine: { had: false, severity: "", time: "", notes: "" } });
    return existing?._id ?? null;
  },
});
```
> Note: `mutation`, `query`, and `v` are already imported in `days.ts`. The `findDay` helper consolidates the repeated index lookup (DRY across the new mutations).

- [ ] **Step 4: Run to verify it passes**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/days.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add convex/days.ts convex/days.test.ts
git commit -m "feat: add setMigraine and removeMigraine mutations"
```

---

## Task 3: Symptoms mutation

**Files:**
- Modify: `convex/days.ts`
- Test: `convex/days.test.ts` (extend)

- [ ] **Step 1: Add failing test**

```typescript
test("setSymptoms upserts symptoms + timestamp", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.days.setSymptoms, {
    userId: "dev-1", date: "2026-06-14", symptoms: ["light", "nausea"], loggedAt: "14:40",
  });
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day?.symptoms).toEqual(["light", "nausea"]);
  expect(day?.symptomsLoggedAt).toBe("14:40");
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/days.test.ts`
Expected: FAIL — `api.days.setSymptoms` undefined.

- [ ] **Step 3: Append to `convex/days.ts`**

```typescript
export const setSymptoms = mutation({
  args: { userId: v.string(), date: v.string(), symptoms: v.array(v.string()), loggedAt: v.string() },
  handler: async (ctx, { userId, date, symptoms, loggedAt }) => {
    const existing = await findDay(ctx, userId, date);
    if (existing) {
      await ctx.db.patch(existing._id, { symptoms, symptomsLoggedAt: loggedAt });
      return existing._id;
    }
    return await ctx.db.insert("days", { userId, date, symptoms, symptomsLoggedAt: loggedAt, foods: [] });
  },
});
```

- [ ] **Step 4: Run to verify it passes** — `npx vitest run convex/days.test.ts` → PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add convex/days.ts convex/days.test.ts
git commit -m "feat: add setSymptoms mutation"
```

---

## Task 4: Food mutations (add/remove)

**Files:**
- Modify: `convex/days.ts`
- Test: `convex/days.test.ts` (extend)

- [ ] **Step 1: Add failing tests**

```typescript
test("addFood appends a food entry", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.days.addFood, {
    userId: "dev-1", date: "2026-06-14",
    food: { name: "Red wine", time: "20:00", note: "", triggers: [{ label: "Alcohol", level: "high", reason: "Vasodilator" }] },
  });
  await t.mutation(api.days.addFood, {
    userId: "dev-1", date: "2026-06-14",
    food: { name: "Toast", time: "08:00", note: "", triggers: [] },
  });
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day?.foods.length).toBe(2);
  expect(day?.foods[0].name).toBe("Red wine");
});

test("removeFood removes by index", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.days.addFood, { userId: "dev-1", date: "2026-06-14", food: { name: "A", time: "08:00", note: "", triggers: [] } });
  await t.mutation(api.days.addFood, { userId: "dev-1", date: "2026-06-14", food: { name: "B", time: "09:00", note: "", triggers: [] } });
  await t.mutation(api.days.removeFood, { userId: "dev-1", date: "2026-06-14", foodIndex: 0 });
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day?.foods.length).toBe(1);
  expect(day?.foods[0].name).toBe("B");
});
```

- [ ] **Step 2: Run to verify it fails** — `npx vitest run convex/days.test.ts` → FAIL.

- [ ] **Step 3: Append to `convex/days.ts`**

```typescript
const foodArg = v.object({
  name: v.string(),
  time: v.string(),
  triggers: v.array(v.object({ label: v.string(), level: v.union(v.literal("low"), v.literal("mid"), v.literal("high")), reason: v.optional(v.string()) })),
  note: v.optional(v.string()),
  imageId: v.optional(v.id("_storage")),
});

export const addFood = mutation({
  args: { userId: v.string(), date: v.string(), food: foodArg },
  handler: async (ctx, { userId, date, food }) => {
    const existing = await findDay(ctx, userId, date);
    if (existing) {
      await ctx.db.patch(existing._id, { foods: [...existing.foods, food] });
      return existing._id;
    }
    return await ctx.db.insert("days", { userId, date, symptoms: [], foods: [food] });
  },
});

export const removeFood = mutation({
  args: { userId: v.string(), date: v.string(), foodIndex: v.number() },
  handler: async (ctx, { userId, date, foodIndex }) => {
    const existing = await findDay(ctx, userId, date);
    if (!existing) return null;
    const foods = existing.foods.filter((_, i) => i !== foodIndex);
    await ctx.db.patch(existing._id, { foods });
    return existing._id;
  },
});
```

- [ ] **Step 4: Run to verify it passes** — `npx vitest run convex/days.test.ts` → PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add convex/days.ts convex/days.test.ts
git commit -m "feat: add addFood and removeFood mutations"
```

---

## Task 5: File storage (upload URL + image URL)

**Files:**
- Create: `convex/files.ts`
- Test: `convex/files.test.ts`

- [ ] **Step 1: Write the failing test** (`getImageUrl` returns null for an unknown id; `generateUploadUrl` returns a string)

```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";

const modules = import.meta.glob("./**/*.ts");

test("getImageUrl returns null for missing storage id", async () => {
  const t = convexTest(schema, modules);
  const url = await t.query(api.files.getImageUrl, { imageId: "nonexistent" });
  expect(url).toBeNull();
});

test("generateUploadUrl returns an upload URL string", async () => {
  const t = convexTest(schema, modules);
  const url = await t.mutation(api.files.generateUploadUrl, {});
  expect(typeof url).toBe("string");
});
```

- [ ] **Step 2: Run to verify it fails** — `npx vitest run convex/files.test.ts` → FAIL.

- [ ] **Step 3: Implement `convex/files.ts`**

```typescript
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => await ctx.storage.generateUploadUrl(),
});

export const getImageUrl = query({
  args: { imageId: v.string() },
  handler: async (ctx, { imageId }) => {
    try {
      return await ctx.storage.getUrl(imageId as any);
    } catch {
      return null;
    }
  },
});
```
> `getImageUrl` takes a plain string (the client stores the id as a string) and tolerates an invalid/missing id by returning null. The `convex-test` mock implements `storage.generateUploadUrl`/`getUrl`.

- [ ] **Step 4: Run to verify it passes** — `npx vitest run convex/files.test.ts` → PASS. (If the convex-test mock does not implement `storage.getUrl` for an arbitrary string and throws instead of returning null, the `try/catch` already returns null — keep it.)

- [ ] **Step 5: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add convex/files.ts convex/files.test.ts
git commit -m "feat: add file storage upload + image url functions"
```

---

## Task 6: `analyzeFood` action

**Files:**
- Create: `convex/ai.ts`
- Test: `convex/ai.test.ts`

The action calls Claude when `ANTHROPIC_API_KEY` is set, parses the JSON, normalizes (`name`→`label`, `medium`→`mid`), and **throws** when the key is absent or the response is unparseable — so the Swift client falls back to the on-device engine.

- [ ] **Step 1: Write the failing test** (key absent → throws; this is the deterministic, network-free path)

```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";

const modules = import.meta.glob("./**/*.ts");

test("analyzeFood throws when no API key is configured", async () => {
  const t = convexTest(schema, modules);
  // No ANTHROPIC_API_KEY in the test env → the action should throw so the client falls back.
  await expect(
    t.action(api.ai.analyzeFood, { description: "aged cheddar toastie" }),
  ).rejects.toThrow();
});
```

- [ ] **Step 2: Run to verify it fails** — `npx vitest run convex/ai.test.ts` → FAIL (`api.ai.analyzeFood` undefined).

- [ ] **Step 3: Implement `convex/ai.ts`**

```typescript
"use node";
import { action } from "./_generated/server";
import { v } from "convex/values";

const LEVELS: Record<string, "low" | "mid" | "high"> = {
  high: "high", medium: "mid", mid: "mid", low: "low",
};

const PROMPT = (desc: string) =>
  `You are a migraine dietary-trigger assistant. A user ate/drank: "${desc}".
Identify likely migraine food triggers present. Common ones: aged cheese (tyramine), cured/processed meats (nitrates), chocolate, caffeine, alcohol (esp. red wine), MSG, aspartame, citrus, fermented foods, nuts, soy sauce, tomatoes.
Reply with ONLY valid minified JSON, no markdown, exactly this shape:
{"label":"short meal name","triggers":[{"name":"Aged cheese","level":"high","reason":"short reason under 8 words"}],"note":"one short calm sentence"}
Rank triggers high→low. level is "high","medium" or "low". If none, use [].`;

export const analyzeFood = action({
  args: { description: v.string() },
  handler: async (_ctx, { description }) => {
    const key = process.env.ANTHROPIC_API_KEY;
    if (!key) throw new Error("ANTHROPIC_API_KEY not configured");

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 512,
        messages: [{ role: "user", content: PROMPT(description) }],
      }),
    });
    if (!res.ok) throw new Error(`Anthropic error ${res.status}`);
    const data = await res.json();
    const text: string = data?.content?.[0]?.text ?? "";
    const clean = text.replace(/```json|```/g, "").trim();
    const parsed = JSON.parse(clean); // throws on bad shape → client falls back

    const triggers = (Array.isArray(parsed.triggers) ? parsed.triggers : []).map((t: any) => ({
      label: String(t.name ?? t.label ?? "Trigger"),
      level: LEVELS[String(t.level).toLowerCase()] ?? "low",
      reason: String(t.reason ?? ""),
    }));
    return {
      label: String(parsed.label ?? description).slice(0, 42),
      triggers,
      note: String(parsed.note ?? ""),
    };
  },
});
```
> `"use node"` runs the action in Convex's Node runtime so `fetch`/`process.env` behave as expected. The action normalizes to our `{label, triggers:[{label,level,reason}], note}` shape with `level ∈ {low,mid,high}` so the Swift `AnalyzedFood` decodes directly.

- [ ] **Step 4: Run to verify it passes** — `npx vitest run convex/ai.test.ts` → PASS (throws without key).

- [ ] **Step 5: Run the whole Convex suite** — `cd /Users/willmorphy/.superset/projects/Migraine && npm test` → all PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add convex/ai.ts convex/ai.test.ts
git commit -m "feat: add analyzeFood action (Claude, throws without key)"
```

- [ ] **Step 7: Push functions to the dev deployment**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx convex dev --once 2>&1 | tail -5`
Expected: functions ready (new mutations/action/queries deployed). (This regenerates `_generated`; no new commit needed unless `_generated` changed — if it did, `git add convex/_generated && git commit -m "chore: regen convex bindings for M2"`.)

---

## Task 7: HavenCore model extensions

**Files:**
- Modify: `HavenCore/Sources/HavenCore/Models.swift`
- Test: `HavenCore/Tests/HavenCoreTests/ModelsTests.swift` (extend)

- [ ] **Step 1: Add a failing test** (decodes a food with note + reason, and back-compat without them)

```swift
@Test func decodesFoodNoteAndReason() throws {
    let json = #"""
    { "userId":"d","date":"2026-06-20","symptoms":[],
      "foods":[{"name":"Red wine","time":"20:00","note":"with dinner",
                "imageId":"kg123",
                "triggers":[{"label":"Alcohol","level":"high","reason":"Vasodilator"}]}] }
    """#
    let day = try JSONDecoder().decode(DayLog.self, from: Data(json.utf8))
    #expect(day.foods.first?.note == "with dinner")
    #expect(day.foods.first?.imageId == "kg123")
    #expect(day.foods.first?.triggers.first?.reason == "Vasodilator")
}

@Test func decodesM1FoodWithoutNewFields() throws {
    let json = #"{ "userId":"d","date":"2026-06-11","symptoms":[],"foods":[{"name":"Toast","time":"08:00","triggers":[]}] }"#
    let day = try JSONDecoder().decode(DayLog.self, from: Data(json.utf8))
    #expect(day.foods.first?.note == nil)
    #expect(day.foods.first?.imageId == nil)
}
```

- [ ] **Step 2: Run to verify it fails** — `swift test --package-path HavenCore` → FAIL (extra members on `TriggerChip`/`FoodEntry` missing).

- [ ] **Step 3: Edit `Models.swift`** — extend the two structs (add the public memberwise inits so tests/UI can construct them):

```swift
public struct TriggerChip: Codable, Sendable, Equatable, Identifiable {
    public let label: String
    public let level: Level
    public let reason: String?
    public var id: String { "\(label)-\(level.rawValue)" }

    public init(label: String, level: Level, reason: String? = nil) {
        self.label = label; self.level = level; self.reason = reason
    }
}

public struct FoodEntry: Codable, Sendable, Equatable {
    public let name: String
    public let time: String          // "HH:mm"
    public let triggers: [TriggerChip]
    public let note: String?
    public let imageId: String?

    public init(name: String, time: String, triggers: [TriggerChip], note: String? = nil, imageId: String? = nil) {
        self.name = name; self.time = time; self.triggers = triggers; self.note = note; self.imageId = imageId
    }
}
```
> Adding explicit memberwise inits with defaults keeps every existing call site (`FoodEntry(name:time:triggers:)`, `TriggerChip(label:level:)`) compiling unchanged. `reason`/`note`/`imageId` decode as nil when absent (optional `let` with Codable synthesis handles missing keys).

- [ ] **Step 4: Run to verify it passes** — `swift test --package-path HavenCore` → PASS (all suites; the new + existing tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add HavenCore/Sources/HavenCore/Models.swift HavenCore/Tests/HavenCoreTests/ModelsTests.swift
git commit -m "feat: extend food/trigger models with note, imageId, reason"
```

---

## Task 8: `TriggerEngine` (on-device fallback)

**Files:**
- Create: `HavenCore/Sources/HavenCore/TriggerEngine.swift`
- Test: `HavenCore/Tests/HavenCoreTests/TriggerEngineTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import HavenCore

@Suite struct TriggerEngineTests {
    @Test func detectsAgedCheeseHigh() {
        let r = TriggerEngine.analyze("aged cheddar toastie")
        #expect(r.triggers.contains { $0.label == "Aged cheese" && $0.level == .high })
    }
    @Test func cleanFoodHasNoTriggers() {
        let r = TriggerEngine.analyze("grilled chicken salad")
        #expect(r.triggers.isEmpty)
    }
    @Test func ordersHighBeforeLow() {
        let r = TriggerEngine.analyze("red wine and dark chocolate") // alcohol high, chocolate mid
        #expect(r.triggers.first?.level == .high)
    }
    @Test func labelIsCapitalizedAndTrimmed() {
        let r = TriggerEngine.analyze("  pepperoni pizza  ")
        #expect(r.label == "Pepperoni pizza")
    }
}
```

- [ ] **Step 2: Run to verify it fails** — `swift test --package-path HavenCore` → FAIL.

- [ ] **Step 3: Implement `TriggerEngine.swift`**

```swift
import Foundation

public struct AnalyzedFood: Codable, Sendable, Equatable {
    public let label: String
    public let triggers: [TriggerChip]
    public let note: String
    public init(label: String, triggers: [TriggerChip], note: String) {
        self.label = label; self.triggers = triggers; self.note = note
    }
}

/// Pure on-device keyword trigger engine (offline fallback for analyzeFood).
public enum TriggerEngine {
    private struct Rule { let pattern: String; let label: String; let level: Level; let reason: String }
    private static let rules: [Rule] = [
        Rule(pattern: "cheese|cheddar|parmesan|brie|blue|gouda|gruy|provolone", label: "Aged cheese", level: .high, reason: "High in tyramine"),
        Rule(pattern: "wine|beer|alcohol|cocktail|whiskey|prosecco|champagne|spirit", label: "Alcohol", level: .high, reason: "Common vasodilator trigger"),
        Rule(pattern: "salami|pepperoni|bacon|hot dog|deli|cured|sausage|ham|prosciutto|nitrate", label: "Cured meat", level: .high, reason: "Contains nitrates"),
        Rule(pattern: "msg|flavou?r enhancer|bouillon|stock cube", label: "MSG", level: .high, reason: "Flavor enhancer"),
        Rule(pattern: "soy sauce|tamari|fish sauce|miso", label: "Soy sauce", level: .mid, reason: "High-tyramine condiment"),
        Rule(pattern: "chocolate|cocoa|cacao", label: "Chocolate", level: .mid, reason: "Caffeine + phenylethylamine"),
        Rule(pattern: "coffee|espresso|caffeine|energy drink|cola|matcha|cold brew", label: "Caffeine", level: .mid, reason: "Excess or withdrawal can trigger"),
        Rule(pattern: "diet|aspartame|sweetener|sugar.?free|zero", label: "Artificial sweetener", level: .mid, reason: "Aspartame sensitivity"),
        Rule(pattern: "citrus|orange|lemon|lime|grapefruit", label: "Citrus", level: .low, reason: "Reported sensitivity in some"),
        Rule(pattern: "onion|garlic|pickle|kimchi|sauerkraut|fermented|yogurt|sourdough|yeast", label: "Fermented / yeast", level: .low, reason: "Histamine + tyramine content"),
        Rule(pattern: "nut|almond|peanut|walnut|pecan|cashew", label: "Nuts", level: .low, reason: "Possible trigger"),
        Rule(pattern: "tomato|marinara|ketchup|salsa", label: "Tomato", level: .low, reason: "Tomato-based foods"),
    ]

    public static func analyze(_ text: String) -> AnalyzedFood {
        let lower = text.lowercased()
        var found: [TriggerChip] = []
        for rule in rules {
            if lower.range(of: rule.pattern, options: .regularExpression) != nil,
               !found.contains(where: { $0.label == rule.label }) {
                found.append(TriggerChip(label: rule.label, level: rule.level, reason: rule.reason))
            }
        }
        let order: [Level: Int] = [.high: 0, .mid: 1, .low: 2]
        found.sort { (order[$0.level] ?? 3) < (order[$1.level] ?? 3) }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let cut = String(collapsed.prefix(42))
        let label = cut.isEmpty ? "Food" : cut.prefix(1).uppercased() + cut.dropFirst()

        return AnalyzedFood(
            label: label,
            triggers: found,
            note: found.isEmpty ? "No obvious dietary triggers spotted." : "Estimated locally from your description.")
    }
}
```

- [ ] **Step 4: Run to verify it passes** — `swift test --package-path HavenCore` → PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add HavenCore/Sources/HavenCore/TriggerEngine.swift HavenCore/Tests/HavenCoreTests/TriggerEngineTests.swift
git commit -m "feat: add on-device TriggerEngine keyword fallback"
```

---

## Task 9: Extend `DayDataSource` + `TodayStore` write methods

**Files:**
- Modify: `HavenCore/Sources/HavenCore/DayDataSource.swift`
- Modify: `HavenCore/Sources/HavenCore/TodayStore.swift`
- Test: `HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift` (extend + extend the FakeSource)

- [ ] **Step 1: Extend the test** — add new methods to `FakeSource` and new tests.

Append new methods to the existing `FakeSource` class:
```swift
    private(set) var savedMigraine: Migraine?
    private(set) var savedSymptoms: [String]?
    private(set) var savedFoods: [FoodEntry] = []
    var analyzeResult: AnalyzedFood = AnalyzedFood(label: "X", triggers: [], note: "n")
    var analyzeShouldThrow = false

    func setMigraine(date: String, migraine: Migraine) async throws {
        savedMigraine = migraine
        let prev = day
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: migraine, symptoms: prev?.symptoms ?? [], symptomsLoggedAt: prev?.symptomsLoggedAt, foods: prev?.foods ?? [])
        onChange?(day)
    }
    func removeMigraine(date: String) async throws {
        savedMigraine = nil
        let prev = day
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: nil, symptoms: prev?.symptoms ?? [], symptomsLoggedAt: prev?.symptomsLoggedAt, foods: prev?.foods ?? [])
        onChange?(day)
    }
    func setSymptoms(date: String, symptoms: [String], loggedAt: String) async throws {
        savedSymptoms = symptoms
        let prev = day
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: prev?.migraine, symptoms: symptoms, symptomsLoggedAt: loggedAt, foods: prev?.foods ?? [])
        onChange?(day)
    }
    func addFood(date: String, food: FoodEntry) async throws {
        savedFoods.append(food)
        let prev = day
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: prev?.migraine, symptoms: prev?.symptoms ?? [], symptomsLoggedAt: prev?.symptomsLoggedAt,
                     foods: (prev?.foods ?? []) + [food])
        onChange?(day)
    }
    func removeFood(date: String, foodIndex: Int) async throws {
        let prev = day
        var foods = prev?.foods ?? []
        if foods.indices.contains(foodIndex) { foods.remove(at: foodIndex) }
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: prev?.migraine, symptoms: prev?.symptoms ?? [], symptomsLoggedAt: prev?.symptomsLoggedAt, foods: foods)
        onChange?(day)
    }
    func analyzeFood(description: String) async throws -> AnalyzedFood {
        if analyzeShouldThrow { throw NSError(domain: "x", code: 1) }
        return analyzeResult
    }
```

Add tests:
```swift
    @Test func saveMigraineWritesAndReflects() async throws {
        let store = TodayStore(source: FakeSource(day: nil), today: "2026-06-14")
        store.start()
        try await store.saveMigraine(Migraine(had: true, severity: "Mild", time: "10:00", notes: ""))
        #expect(store.day?.migraine?.had == true)
        #expect(store.ledger.contains { $0.kind == .migraine })
    }
    @Test func saveFoodAppendsToLedger() async throws {
        let store = TodayStore(source: FakeSource(day: nil), today: "2026-06-14")
        store.start()
        try await store.saveFood(FoodEntry(name: "Wine", time: "20:00", triggers: []))
        #expect(store.ledger.contains { $0.kind == .food })
    }
    @Test func analyzeUsesActionThenFallsBack() async throws {
        let src = FakeSource(day: nil)
        src.analyzeResult = AnalyzedFood(label: "Cheese", triggers: [TriggerChip(label: "Aged cheese", level: .high)], note: "n")
        let store = TodayStore(source: src, today: "2026-06-14")
        let ok = await store.analyze("aged cheddar")
        #expect(ok.label == "Cheese")               // action path
        src.analyzeShouldThrow = true
        let fb = await store.analyze("aged cheddar") // falls back to on-device engine
        #expect(fb.triggers.contains { $0.label == "Aged cheese" })
    }
```

- [ ] **Step 2: Run to verify it fails** — `swift test --package-path HavenCore` → FAIL (FakeSource won't conform; store methods missing).

- [ ] **Step 3: Extend `DayDataSource.swift`** — add to the protocol:

```swift
    func setMigraine(date: String, migraine: Migraine) async throws
    func removeMigraine(date: String) async throws
    func setSymptoms(date: String, symptoms: [String], loggedAt: String) async throws
    func addFood(date: String, food: FoodEntry) async throws
    func removeFood(date: String, foodIndex: Int) async throws
    func analyzeFood(description: String) async throws -> AnalyzedFood
```

- [ ] **Step 4: Extend `TodayStore.swift`** — add methods (the `analyze` is the two-tier orchestration):

```swift
    public func saveMigraine(_ migraine: Migraine) async throws {
        try await source.setMigraine(date: today, migraine: migraine)
    }
    public func removeMigraine() async throws { try await source.removeMigraine(date: today) }
    public func saveSymptoms(_ symptoms: [String], at time: String? = nil) async throws {
        try await source.setSymptoms(date: today, symptoms: symptoms, loggedAt: time ?? Self.nowHM())
    }
    public func saveFood(_ food: FoodEntry) async throws { try await source.addFood(date: today, food: food) }
    public func removeFood(at index: Int) async throws { try await source.removeFood(date: today, foodIndex: index) }

    /// Two-tier: try the server action; on any error fall back to the on-device engine.
    public func analyze(_ description: String) async -> AnalyzedFood {
        do { return try await source.analyzeFood(description: description) }
        catch { return TriggerEngine.analyze(description) }
    }
```

- [ ] **Step 5: Run to verify it passes** — `swift test --package-path HavenCore` → PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/willmorphy/.superset/projects/Migraine
git add HavenCore/Sources/HavenCore/DayDataSource.swift HavenCore/Sources/HavenCore/TodayStore.swift HavenCore/Tests/HavenCoreTests/TodayStoreTests.swift
git commit -m "feat: add logging write methods and two-tier analyze to TodayStore"
```

---

## Definition of done (M2-P1)
1. `npm test` passes (schema + migraine/symptoms/food mutations + files + analyzeFood-throws).
2. `swift test --package-path HavenCore` passes (extended models back-compat, TriggerEngine, store write/analyze methods).
3. New Convex functions deployed to the dev deployment (`npx convex dev --once`).
4. No UI yet — M2-P2 consumes this.

---

## Self-review notes
- **Spec coverage:** schema §4 (T1), mutations §5 (T2–T5), analyzeFood §5 + contract (T6), TriggerEngine §6 (T8), model extensions §4 (T7), store/protocol §7.4 (T9). File storage §5 (T5).
- **Type consistency:** `Migraine` arg shape matches the existing model (had/severity/time/notes). `foodArg`/`FoodEntry` align (name/time/triggers/note/imageId). `analyzeFood` returns `{label, triggers:[{label,level,reason}], note}` = Swift `AnalyzedFood`. Level union low/mid/high everywhere; LLM `medium`→`mid` normalized in T6. `findDay` helper reused across T2–T4.
- **Back-compat:** all schema/model additions optional; M1 seed + getDay still decode (T7 has an explicit back-compat test). Existing `setFactors`/`getDay` untouched.
- **Risk:** `convex-test` storage mock behavior for `getImageUrl` — the try/catch returns null regardless. `analyzeFood` live path is not unit-tested (network); only the throws-without-key path is, which is exactly the fallback trigger the client relies on.
