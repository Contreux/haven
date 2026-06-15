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

test("completeOnboarding sets onboarded + fields", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.completeOnboarding, {
    userId: "dev-1", answers: '{"frequency":"weekly"}', reminderTime: "evening", lat: 51.5, lon: -0.1,
  });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.onboarded).toBe(true);
  expect(s.reminderTime).toBe("evening");
});
test("getSettings defaults onboarded/subscribed false", async () => {
  const t = convexTest(schema, modules);
  const s = await t.query(api.settings.getSettings, { userId: "new" });
  expect(s.onboarded).toBe(false);
  expect(s.subscribed).toBe(false);
});
test("setSubscribed flips subscribed", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.setSubscribed, { userId: "dev-1", subscribed: true });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.subscribed).toBe(true);
});

test("updateAnswers patches answers, keeps onboarded", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.completeOnboarding, { userId: "dev-1", answers: '{"frequency":["weekly"]}', reminderTime: "evening" });
  await t.mutation(api.settings.updateAnswers, { userId: "dev-1", answers: '{"frequency":["chronic"]}' });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.answers).toBe('{"frequency":["chronic"]}');
  expect(s.onboarded).toBe(true);
});

test("setReminderTime patches reminder", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.setReminderTime, { userId: "dev-1", reminderTime: "morning" });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.reminderTime).toBe("morning");
});

test("deleteAccount removes the settings row (re-gates to onboarding)", async () => {
  const t = convexTest(schema, modules);
  await t.mutation(api.settings.setSubscribed, { userId: "dev-1", subscribed: true });
  await t.mutation(api.settings.deleteAccount, { userId: "dev-1" });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.onboarded).toBe(false);
});
