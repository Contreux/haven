import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";

const modules = import.meta.glob("./**/*.ts");

test("getImageUrl returns null for missing storage id", async () => {
  const t = convexTest(schema, modules);
  const url = await t.query(api.files.getImageUrl, { imageId: "nonexistent" });
  expect(url).toBeNull();
});

test("generateUploadUrl returns an upload URL string", async () => {
  const t = convexTest(schema, modules);
  const url = await t.mutation(api.files.generateUploadUrl, {});
  expect(typeof url).toBe("string");
});
