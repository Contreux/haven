import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const getSettings = query({
  args: { userId: v.string() },
  handler: async (ctx, { userId }) => {
    const row = await ctx.db
      .query("settings")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .unique();
    return { theme: row?.theme ?? "dark" };
  },
});

export const updateSettings = mutation({
  args: { userId: v.string(), theme: v.string() },
  handler: async (ctx, { userId, theme }) => {
    const existing = await ctx.db
      .query("settings")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .unique();
    if (existing) {
      await ctx.db.patch(existing._id, { theme });
      return existing._id;
    }
    return await ctx.db.insert("settings", { userId, theme });
  },
});
