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
