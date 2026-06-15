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

test("setSymptoms upserts symptoms + timestamp", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.days.setSymptoms, {
    userId: "dev-1", date: "2026-06-14", symptoms: ["light", "nausea"], loggedAt: "14:40",
  });
  const day = await t.query(api.days.getDay, { userId: "dev-1", date: "2026-06-14" });
  expect(day?.symptoms).toEqual(["light", "nausea"]);
  expect(day?.symptomsLoggedAt).toBe("14:40");
});

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
