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

test("analyzeFoodImage throws when no API key is configured", async () => {
  const t = convexTest(schema, modules);
  await expect(
    t.action(api.ai.analyzeFoodImage, { imageBase64: "QUJD" }),
  ).rejects.toThrow();
});
