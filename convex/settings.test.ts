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
