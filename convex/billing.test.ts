import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";
const modules = import.meta.glob("./**/*.ts");
test("validateSubscription marks the user subscribed", async () => {
  const t = convexTest(schema, modules);
  await t.action(api.billing.validateSubscription, { userId: "dev-1", transactionId: "tx-1" });
  const s = await t.query(api.settings.getSettings, { userId: "dev-1" });
  expect(s.subscribed).toBe(true);
});
