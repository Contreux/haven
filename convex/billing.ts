import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";

export const validateSubscription = action({
  args: { userId: v.string(), transactionId: v.string() },
  handler: async (ctx, { userId, transactionId }) => {
    // M5: trust the client-verified StoreKit 2 transaction and record entitlement.
    // Launch step: verify `transactionId` against Apple's verifyReceipt / App Store Server API.
    await ctx.runMutation(api.settings.setSubscribed, { userId, subscribed: true });
    return { ok: true };
  },
});
