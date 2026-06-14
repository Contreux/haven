import { query } from "./_generated/server";
import { v } from "convex/values";

export const getDay = query({
  args: { userId: v.string(), date: v.string() },
  handler: async (ctx, { userId, date }) => {
    return await ctx.db
      .query("days")
      .withIndex("by_user_date", (q) => q.eq("userId", userId).eq("date", date))
      .unique();
  },
});
