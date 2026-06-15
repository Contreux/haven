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
