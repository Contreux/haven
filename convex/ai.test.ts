import { convexTest } from "convex-test";
import { describe, expect, it, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";
import { firstImageBase64 } from "./ai";

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

describe("firstImageBase64", () => {
  it("returns the b64 string when present", () => {
    expect(firstImageBase64({ data: [{ b64_json: "AAAA" }] })).toBe("AAAA");
  });
  it("returns null for empty/missing data", () => {
    expect(firstImageBase64({ data: [] })).toBeNull();
    expect(firstImageBase64({})).toBeNull();
    expect(firstImageBase64({ data: [{ b64_json: "" }] })).toBeNull();
  });
});
