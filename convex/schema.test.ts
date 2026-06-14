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
