# Haven M1 · Plan 2 — Convex Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Convex deployment for Haven — schema, queries, mutations (including the M1 write path and a demo seeder) — driven entirely from the terminal and covered by `convex-test` function tests, so the Today client (P3) has a real, reactive backend to read from and write to.

**Architecture:** A Convex project under `convex/` with a single `days` table (the day log, with embedded `foods`/`migraine`/`symptoms`/`factors` so one `getDay` read returns everything the ledger needs) plus a `settings` table. All functions are scoped by a **device id passed as an argument** (`userId` field) — no login UI, satisfying the M1 "device identity" decision; real `ctx.auth` accounts are deferred to M5. Logic is tested headlessly with `convex-test` + Vitest (`edge-runtime`), so no live deployment is required to run the suite.

**Tech Stack:** Convex (TypeScript functions) · `convex` CLI (`npx convex dev`) · `convex-test` + Vitest + `@edge-runtime/vm`.

**Reference docs:** `docs/superpowers/specs/2026-06-14-haven-m1-foundation-today-design.md` (§5, §6.5), `README.md` (data model). convex-test usage: https://docs.convex.dev/testing/convex-test.

---

## Scope & dependencies

- **Depends on:** nothing in the repo (independent of P1). Needs Node + `npx` (already verified present).
- **Produces:** a deployable Convex backend + a green `convex-test` suite. The deployment URL it prints is what P3's `ConvexService` connects to.
- **Out of scope:** the Swift client (P3), real `ctx.auth` accounts (M5), food photo capture + storage + the standalone `foods` table (M2), the `fetchWeather`/`analyzeFood` actions (M4).

## Design reconciliations (locked here)

1. **Identity = device id argument.** Every function that touches user data takes `userId: v.string()` (a client-persisted device UUID). This is the M1 "anonymous/device identity, no login UI" from spec decision #4. `ctx.auth` is M5.
2. **Foods are embedded on the day** (`days.foods[]`), per ledger §6.5, not the separate `foods` table from §5.1. The standalone table is M2.

## Data shapes (single source of truth for both plans)

A `days` document:

```jsonc
{
  "userId": "device-uuid",
  "date": "2026-06-14",                       // YYYY-MM-DD
  "factors": {                                // optional
    "sleepHours": 6.5,
    "stress": "high",                         // "low" | "mid" | "high"
    "hydration": "low",                       // "low" | "mid" | "high"
    "weatherSensitive": true
  },
  "factorsLoggedAt": "09:02",                 // optional · ledger timestamp "HH:mm"
  "migraine": {                               // optional
    "had": true,
    "severity": "moderate",
    "time": "15:10",
    "notes": "behind left eye"
  },
  "symptoms": ["nausea", "aura"],             // array (may be empty)
  "symptomsLoggedAt": "14:40",                // optional · ledger timestamp
  "foods": [                                  // array (may be empty)
    { "name": "Aged cheddar", "time": "12:30",
      "triggers": [ { "label": "Tyramine", "level": "high" } ] }
  ]
}
```

A `settings` document: `{ "userId": "device-uuid", "theme": "dark" }`.

---

## Task 1: Node/Convex project init + Vitest wiring

**Files:**
- Create: `package.json`
- Create: `vitest.config.ts`
- Create: `tsconfig.json`
- Create: `convex/tsconfig.json`

- [ ] **Step 1: Write `package.json`**

```json
{
  "name": "haven-backend",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "convex dev",
    "deploy": "convex deploy",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "devDependencies": {
    "convex": "latest",
    "convex-test": "latest",
    "vitest": "latest",
    "@edge-runtime/vm": "latest",
    "typescript": "latest"
  }
}
```

- [ ] **Step 2: Write `vitest.config.ts`**

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "edge-runtime",
    server: { deps: { inline: ["convex-test"] } },
  },
});
```

- [ ] **Step 3: Write `tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "types": ["vite/client"]
  },
  "include": ["convex", "vitest.config.ts"]
}
```

- [ ] **Step 4: Write `convex/tsconfig.json`**

```json
{
  "extends": "../tsconfig.json",
  "include": ["./**/*"]
}
```

- [ ] **Step 5: Install dependencies**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && npm install
```
Expected: `node_modules/` populated; `convex`, `convex-test`, `vitest` present. (`.gitignore` from P1 already ignores `node_modules/`; if P1 hasn't run, add `node_modules/` to `.gitignore` now.)

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json vitest.config.ts tsconfig.json convex/tsconfig.json
git commit -m "chore: init Convex backend project with Vitest"
```

---

## Task 2: Schema

**Files:**
- Create: `convex/schema.ts`
- Test: `convex/schema.test.ts`

- [ ] **Step 1: Write the failing test** (proves the schema loads and a `days` row round-trips via `t.run`)

```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";

const modules = import.meta.glob("./**/*.ts");

test("days table accepts a full day document", async () => {
  const t = convexTest(schema, modules);
  const id = await t.run(async (ctx) =>
    ctx.db.insert("days", {
      userId: "dev-1",
      date: "2026-06-14",
      symptoms: ["nausea"],
      foods: [{ name: "Cheddar", time: "12:30", triggers: [{ label: "Tyramine", level: "high" }] }],
    }),
  );
  const doc = await t.run(async (ctx) => ctx.db.get(id));
  expect(doc?.date).toBe("2026-06-14");
  expect(doc?.foods[0].triggers[0].level).toBe("high");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/schema.test.ts`
Expected: FAIL — `./schema` has no default export / module missing.

- [ ] **Step 3: Implement `convex/schema.ts`**

```typescript
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

const level = v.union(v.literal("low"), v.literal("mid"), v.literal("high"));

const triggerChip = v.object({
  label: v.string(),
  level: level,
});

const foodEntry = v.object({
  name: v.string(),
  time: v.string(), // "HH:mm"
  triggers: v.array(triggerChip),
});

export default defineSchema({
  days: defineTable({
    userId: v.string(),
    date: v.string(), // "YYYY-MM-DD"
    factors: v.optional(
      v.object({
        sleepHours: v.number(),
        stress: level,
        hydration: level,
        weatherSensitive: v.boolean(),
      }),
    ),
    factorsLoggedAt: v.optional(v.string()), // "HH:mm"
    migraine: v.optional(
      v.object({
        had: v.boolean(),
        severity: v.string(),
        time: v.string(),
        notes: v.string(),
      }),
    ),
    symptoms: v.array(v.string()),
    symptomsLoggedAt: v.optional(v.string()),
    foods: v.array(foodEntry),
  }).index("by_user_date", ["userId", "date"]),

  settings: defineTable({
    userId: v.string(),
    theme: v.string(),
  }).index("by_user", ["userId"]),
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/schema.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add convex/schema.ts convex/schema.test.ts
git commit -m "feat: add Convex schema for days and settings"
```

---

## Task 3: `getDay` query

**Files:**
- Create: `convex/days.ts`
- Test: `convex/days.test.ts`

- [ ] **Step 1: Write the failing test**

```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";

const modules = import.meta.glob("./**/*.ts");

test("getDay returns null when no log exists", async () => {
  const t = convexTest(schema, modules);
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day).toBeNull();
});

test("getDay returns the matching day scoped to the device", async () => {
  const t = convexTest(schema, modules);
  await t.run(async (ctx) => {
    await ctx.db.insert("days", { userId: "dev-1", date: "2026-06-14", symptoms: [], foods: [] });
    await ctx.db.insert("days", { userId: "dev-2", date: "2026-06-14", symptoms: ["nausea"], foods: [] });
  });
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day?.userId).toBe("dev-1");
  expect(day?.symptoms).toEqual([]);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/days.test.ts`
Expected: FAIL — `api.days.getDay` undefined (`_generated` not built / function missing).

- [ ] **Step 3: Implement `getDay` in `convex/days.ts`**

```typescript
import { query } from "./_generated/server";
import { v } from "convex/values";

export const getDay = query({
  args: { userId: v.string(), date: v.string() },
  handler: async (ctx, { userId, date }) => {
    return await ctx.db
      .query("days")
      .withIndex("by_user_date", (q) => q.eq("userId", userId).eq("date", date))
      .unique();
  },
});
```

> `convex-test` generates `_generated` from the schema/modules at test time via `import.meta.glob`; you do not need a live deployment for the test to resolve `api.days.getDay`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/days.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add convex/days.ts convex/days.test.ts
git commit -m "feat: add getDay query scoped by device id"
```

---

## Task 4: `setFactors` mutation — the M1 write path

Upsert semantics: first call creates the day with factors; a second call updates the same day in place.

**Files:**
- Modify: `convex/days.ts`
- Test: `convex/days.test.ts` (extend)

- [ ] **Step 1: Add the failing tests**

```typescript
test("setFactors creates a day when none exists", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.days.setFactors, {
    userId: "dev-1",
    date: "2026-06-14",
    factors: { sleepHours: 6.5, stress: "high", hydration: "low", weatherSensitive: true },
    loggedAt: "09:02",
  });
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day?.factors?.sleepHours).toBe(6.5);
  expect(day?.factorsLoggedAt).toBe("09:02");
  expect(day?.symptoms).toEqual([]);
  expect(day?.foods).toEqual([]);
});

test("setFactors updates the existing day in place (no duplicate)", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.days.setFactors, {
    userId: "dev-1", date: "2026-06-14",
    factors: { sleepHours: 6.5, stress: "high", hydration: "low", weatherSensitive: true },
    loggedAt: "09:02",
  });
  await t.mutation(api.days.setFactors, {
    userId: "dev-1", date: "2026-06-14",
    factors: { sleepHours: 8, stress: "low", hydration: "mid", weatherSensitive: false },
    loggedAt: "10:15",
  });
  const all = await t.run(async (ctx) =>
    ctx.db.query("days").withIndex("by_user_date", (q) => q.eq("userId", "dev-1").eq("date", "2026-06-14")).collect(),
  );
  expect(all.length).toBe(1);
  expect(all[0].factors?.sleepHours).toBe(8);
  expect(all[0].factorsLoggedAt).toBe("10:15");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/days.test.ts`
Expected: FAIL — `api.days.setFactors` undefined.

- [ ] **Step 3: Implement `setFactors` (append to `convex/days.ts`)**

```typescript
import { mutation } from "./_generated/server";

const factorsArg = v.object({
  sleepHours: v.number(),
  stress: v.union(v.literal("low"), v.literal("mid"), v.literal("high")),
  hydration: v.union(v.literal("low"), v.literal("mid"), v.literal("high")),
  weatherSensitive: v.boolean(),
});

export const setFactors = mutation({
  args: {
    userId: v.string(),
    date: v.string(),
    factors: factorsArg,
    loggedAt: v.string(),
  },
  handler: async (ctx, { userId, date, factors, loggedAt }) => {
    const existing = await ctx.db
      .query("days")
      .withIndex("by_user_date", (q) => q.eq("userId", userId).eq("date", date))
      .unique();
    if (existing) {
      await ctx.db.patch(existing._id, { factors, factorsLoggedAt: loggedAt });
      return existing._id;
    }
    return await ctx.db.insert("days", {
      userId,
      date,
      factors,
      factorsLoggedAt: loggedAt,
      symptoms: [],
      foods: [],
    });
  },
});
```

> `import` statements: add `mutation` to the import from `./_generated/server` already used by `getDay` (keep a single import line). `v` is already imported.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/days.test.ts`
Expected: PASS (4 tests total in the file).

- [ ] **Step 5: Commit**

```bash
git add convex/days.ts convex/days.test.ts
git commit -m "feat: add setFactors upsert mutation (M1 write path)"
```

---

## Task 5: Settings query + mutation

**Files:**
- Create: `convex/settings.ts`
- Test: `convex/settings.test.ts`

- [ ] **Step 1: Write the failing test**

```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";

const modules = import.meta.glob("./**/*.ts");

test("getSettings defaults to dark when unset", async () => {
  const t = convexTest(schema, modules);
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.theme).toBe("dark");
});

test("updateSettings persists the theme and getSettings reflects it", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.updateSettings, { userId: "dev-1", theme: "light" });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.theme).toBe("light");
});

test("updateSettings updates in place (single row per device)", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.updateSettings, { userId: "dev-1", theme: "light" });
  await t.mutation(api.settings.updateSettings, { userId: "dev-1", theme: "dark" });
  const rows = await t.run(async (ctx) =>
    ctx.db.query("settings").withIndex("by_user", (q) => q.eq("userId", "dev-1")).collect(),
  );
  expect(rows.length).toBe(1);
  expect(rows[0].theme).toBe("dark");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/settings.test.ts`
Expected: FAIL — `api.settings.*` undefined.

- [ ] **Step 3: Implement `convex/settings.ts`**

```typescript
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const getSettings = query({
  args: { userId: v.string() },
  handler: async (ctx, { userId }) => {
    const row = await ctx.db
      .query("settings")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .unique();
    return { theme: row?.theme ?? "dark" };
  },
});

export const updateSettings = mutation({
  args: { userId: v.string(), theme: v.string() },
  handler: async (ctx, { userId, theme }) => {
    const existing = await ctx.db
      .query("settings")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .unique();
    if (existing) {
      await ctx.db.patch(existing._id, { theme });
      return existing._id;
    }
    return await ctx.db.insert("settings", { userId, theme });
  },
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/settings.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add convex/settings.ts convex/settings.test.ts
git commit -m "feat: add settings query and mutation"
```

---

## Task 6: `seed` mutation — demo days so Today looks alive

Seeds a deterministic range of recent days for one device: a mix of foods, a migraine, symptoms, and factors, with ledger timestamps, so P3's screen and the streak look real.

**Files:**
- Create: `convex/seed.ts`
- Test: `convex/seed.test.ts`

- [ ] **Step 1: Write the failing test**

```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";

const modules = import.meta.glob("./**/*.ts");

test("seed creates several days for the device including today", async () => {
  const t = convexTest(schema, modules);
  const count = await t.mutation(api.seed.seed, { userId: "dev-1", today: "2026-06-14" });
  expect(count).toBeGreaterThanOrEqual(3);

  const today = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(today).not.toBeNull();
  // today should have a populated ledger surface: foods + migraine + symptoms
  expect(today!.foods.length).toBeGreaterThan(0);
  expect(today!.migraine?.had).toBe(true);
  expect(today!.symptoms.length).toBeGreaterThan(0);
  expect(today!.symptomsLoggedAt).toBeTruthy();
});

test("seed is idempotent for a device+date (re-seed replaces, no duplicates)", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.seed.seed, { userId: "dev-1", today: "2026-06-14" });
  await t.mutation(api.seed.seed, { userId: "dev-1", today: "2026-06-14" });
  const todayRows = await t.run(async (ctx) =>
    ctx.db.query("days").withIndex("by_user_date", (q) => q.eq("userId", "dev-1").eq("date", "2026-06-14")).collect(),
  );
  expect(todayRows.length).toBe(1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/seed.test.ts`
Expected: FAIL — `api.seed.seed` undefined.

- [ ] **Step 3: Implement `convex/seed.ts`**

```typescript
import { mutation } from "./_generated/server";
import { v } from "convex/values";

// Subtract `n` days from a "YYYY-MM-DD" string, returning the same format.
function minusDays(date: string, n: number): string {
  const d = new Date(date + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() - n);
  return d.toISOString().slice(0, 10);
}

export const seed = mutation({
  args: { userId: v.string(), today: v.string() },
  handler: async (ctx, { userId, today }) => {
    const dates = [today, minusDays(today, 1), minusDays(today, 2), minusDays(today, 3)];

    // Clear any existing rows for these dates so re-seeding is idempotent.
    for (const date of dates) {
      const rows = await ctx.db
        .query("days")
        .withIndex("by_user_date", (q) => q.eq("userId", userId).eq("date", date))
        .collect();
      for (const row of rows) await ctx.db.delete(row._id);
    }

    // Today — full, lively day (drives the ledger + the migraine alert + summary).
    await ctx.db.insert("days", {
      userId,
      date: dates[0],
      factors: { sleepHours: 6.5, stress: "high", hydration: "low", weatherSensitive: true },
      factorsLoggedAt: "09:02",
      migraine: { had: true, severity: "moderate", time: "15:10", notes: "Behind the left eye" },
      symptoms: ["nausea", "aura"],
      symptomsLoggedAt: "14:40",
      foods: [
        { name: "Oat latte", time: "08:15", triggers: [] },
        { name: "Aged cheddar", time: "12:30", triggers: [{ label: "Tyramine", level: "high" }] },
        { name: "Dark chocolate", time: "16:05", triggers: [{ label: "Caffeine", level: "mid" }] },
      ],
    });

    // Yesterday — calm day, no migraine.
    await ctx.db.insert("days", {
      userId,
      date: dates[1],
      factors: { sleepHours: 8, stress: "low", hydration: "mid", weatherSensitive: true },
      factorsLoggedAt: "08:30",
      symptoms: [],
      symptomsLoggedAt: undefined,
      foods: [{ name: "Greek yogurt", time: "09:00", triggers: [] }],
    });

    // Two days ago — a migraine day.
    await ctx.db.insert("days", {
      userId,
      date: dates[2],
      factors: { sleepHours: 5.5, stress: "mid", hydration: "low", weatherSensitive: true },
      factorsLoggedAt: "10:10",
      migraine: { had: true, severity: "severe", time: "18:40", notes: "Storm front" },
      symptoms: ["light sensitivity"],
      symptomsLoggedAt: "18:00",
      foods: [{ name: "Red wine", time: "19:30", triggers: [{ label: "Histamine", level: "high" }] }],
    });

    // Three days ago — minimal entry (keeps the streak going).
    await ctx.db.insert("days", {
      userId,
      date: dates[3],
      symptoms: [],
      foods: [{ name: "Toast", time: "08:00", triggers: [] }],
    });

    return dates.length;
  },
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npx vitest run convex/seed.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Run the whole suite**

Run: `cd /Users/willmorphy/.superset/projects/Migraine && npm test`
Expected: all tests across `schema`, `days`, `settings`, `seed` PASS.

- [ ] **Step 6: Commit**

```bash
git add convex/seed.ts convex/seed.test.ts
git commit -m "feat: add seed mutation for demo days"
```

---

## Task 7: Provision the deployment (terminal) + capture the URL

This is the only step that talks to Convex's cloud. It is required so P3 has a real deployment URL, but the test suite above does **not** depend on it.

- [ ] **Step 1: Start the dev deployment**

Run (interactive the first time — it will prompt to create/login a project; this is CLI-only, no web dashboard required):
```bash
cd /Users/willmorphy/.superset/projects/Migraine && npx convex dev --once
```
Expected: Convex pushes the schema + functions and prints a deployment URL like `https://<name>.convex.cloud`. A `.env.local` with `CONVEX_DEPLOYMENT` and `CONVEX_URL` is written, and `convex/_generated/` is created.

> If login must happen in this session, tell the user to run `! npx convex login` so the device-auth output lands in the conversation.

- [ ] **Step 2: Record the URL for P3**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && cat .env.local
```
Expected: shows `CONVEX_URL=https://<name>.convex.cloud`. **P3 Task 8 hardcodes/loads this URL.** Note it.

- [ ] **Step 3: Seed the live deployment so the app has data**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && npx convex run seed:seed '{"userId":"sim-device","today":"2026-06-14"}'
```
Expected: returns `4`. (`sim-device` is the fixed device id the simulator will use in P3 dev builds.)

- [ ] **Step 4: Verify the data over the CLI**

Run:
```bash
cd /Users/willmorphy/.superset/projects/Migraine && npx convex run days:getDay '{"userId":"sim-device","date":"2026-06-14"}'
```
Expected: prints the seeded today document with `foods`, `migraine`, and `symptoms`.

- [ ] **Step 5: Commit the generated bindings + env example**

```bash
# .env.local is gitignored (secrets); commit a documented example instead.
printf 'CONVEX_URL=https://<your-deployment>.convex.cloud\n' > .env.example
git add .env.example convex/_generated
git commit -m "chore: provision Convex dev deployment and generated bindings"
```

> Confirm `.gitignore` ignores `.env.local`. If P1's `.gitignore` doesn't list it, add `.env.local` before committing.

---

## Definition of done (P2)

1. `npm test` passes the full `convex-test` suite (schema, getDay, setFactors upsert, settings, seed idempotency + device scoping).
2. `npx convex dev --once` deploys schema + functions from a clean checkout — terminal only, no dashboard.
3. `npx convex run seed:seed …` then `npx convex run days:getDay …` returns lively seeded data for `sim-device`.
4. The deployment URL is recorded for P3.

---

## Self-review notes

- **Spec coverage (§5):** schema days/settings (T2; foods embedded per §6.5 reconciliation, standalone foods table deferred to M2), getDay/getSettings (T3, T5), setFactors/updateSettings/seed (T4, T5, T6), identity (device-id arg per decision #4; T3+ all scope by `userId`). Weather stub (§5.4) is client-side → P3.
- **Type consistency:** `level` union (`low|mid|high`) is reused for factors stress/hydration and trigger chips, matching `FactorLevel` in P1 and the `Codable` models in P3. `factors.sleepHours` (number), `factorsLoggedAt`/`symptomsLoggedAt` ("HH:mm"), `foods[].time` ("HH:mm") are the exact field names P3's models decode — do not rename without updating P3.
- **No placeholders:** every function and test is complete. The only human-interactive step is `npx convex dev` login (T7 S1), which is inherent to provisioning and flagged with the `! npx convex login` fallback.
- **Risk:** `convex-test`'s `import.meta.glob` requires the Vitest `edge-runtime` environment (set in T1). If `api.*` fails to resolve in tests, confirm `convex/_generated` exists (created by T7 S1) — `convex-test` can synthesize it from `modules`, but running `npx convex codegen` once removes any ambiguity.
