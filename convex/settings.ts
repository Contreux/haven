import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const getSettings = query({
  args: { userId: v.string() },
  handler: async (ctx, { userId }) => {
    const row = await ctx.db
      .query("settings")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .unique();
    return {
      theme: row?.theme ?? "dark",
      onboarded: row?.onboarded ?? false,
      answers: row?.answers ?? "",
      reminderTime: row?.reminderTime ?? "",
      lat: row?.lat ?? null,
      lon: row?.lon ?? null,
      subscribed: row?.subscribed ?? false,
    };
  },
});

async function upsertSettings(ctx: any, userId: string, patch: Record<string, unknown>) {
  const existing = await ctx.db.query("settings").withIndex("by_user", (q: any) => q.eq("userId", userId)).unique();
  if (existing) { await ctx.db.patch(existing._id, patch); return existing._id; }
  return await ctx.db.insert("settings", { userId, theme: "dark", ...patch });
}

export const completeOnboarding = mutation({
  args: { userId: v.string(), answers: v.string(), reminderTime: v.optional(v.string()), lat: v.optional(v.number()), lon: v.optional(v.number()) },
  handler: async (ctx, { userId, answers, reminderTime, lat, lon }) =>
    await upsertSettings(ctx, userId, { onboarded: true, answers, reminderTime, lat, lon }),
});

export const setSubscribed = mutation({
  args: { userId: v.string(), subscribed: v.boolean() },
  handler: async (ctx, { userId, subscribed }) => await upsertSettings(ctx, userId, { subscribed }),
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

export const updateAnswers = mutation({
  args: { userId: v.string(), answers: v.string() },
  handler: async (ctx, { userId, answers }) => await upsertSettings(ctx, userId, { answers }),
});

export const setReminderTime = mutation({
  args: { userId: v.string(), reminderTime: v.string() },
  handler: async (ctx, { userId, reminderTime }) => await upsertSettings(ctx, userId, { reminderTime }),
});

export const deleteAccount = mutation({
  args: { userId: v.string() },
  handler: async (ctx, { userId }) => {
    const row = await ctx.db.query("settings").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    if (row) await ctx.db.delete(row._id);
  },
});
