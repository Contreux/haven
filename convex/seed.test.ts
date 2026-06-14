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
