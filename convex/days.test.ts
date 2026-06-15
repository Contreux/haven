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
