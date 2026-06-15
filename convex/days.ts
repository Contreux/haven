import { query, mutation } from "./_generated/server";
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

const factorsArg = v.object({
  sleepHours: v.number(),
  stress: v.union(v.literal("low"), v.literal("mid"), v.literal("high")),
  hydration: v.union(v.literal("low"), v.literal("mid"), v.literal("high")),
  weatherSensitive: v.boolean(),
});

export const setFactors = mutation({
  args: {
    userId: v.string(),
    date: v.string(),
    factors: factorsArg,
    loggedAt: v.string(),
  },
  handler: async (ctx, { userId, date, factors, loggedAt }) => {
    const existing = await ctx.db
      .query("days")
      .withIndex("by_user_date", (q) => q.eq("userId", userId).eq("date", date))
      .unique();
    if (existing) {
      await ctx.db.patch(existing._id, { factors, factorsLoggedAt: loggedAt });
      return existing._id;
    }
    return await ctx.db.insert("days", {
      userId,
      date,
      factors,
      factorsLoggedAt: loggedAt,
      symptoms: [],
      foods: [],
    });
  },
});

const migraineArg = v.object({
  had: v.boolean(),
  severity: v.string(),
  time: v.string(),
  notes: v.string(),
});

// Find-or-create the day row for (userId, date); returns the existing doc or null.
async function findDay(ctx: any, userId: string, date: string) {
  return await ctx.db
    .query("days")
    .withIndex("by_user_date", (q: any) => q.eq("userId", userId).eq("date", date))
    .unique();
}

export const setMigraine = mutation({
  args: { userId: v.string(), date: v.string(), migraine: migraineArg },
  handler: async (ctx, { userId, date, migraine }) => {
    const existing = await findDay(ctx, userId, date);
    if (existing) {
      await ctx.db.patch(existing._id, { migraine });
      return existing._id;
    }
    return await ctx.db.insert("days", { userId, date, migraine, symptoms: [], foods: [] });
  },
});

export const removeMigraine = mutation({
  args: { userId: v.string(), date: v.string() },
  handler: async (ctx, { userId, date }) => {
    const existing = await findDay(ctx, userId, date);
    if (existing) await ctx.db.patch(existing._id, { migraine: { had: false, severity: "", time: "", notes: "" } });
    return existing?._id ?? null;
  },
});

export const setSymptoms = mutation({
  args: { userId: v.string(), date: v.string(), symptoms: v.array(v.string()), loggedAt: v.string() },
  handler: async (ctx, { userId, date, symptoms, loggedAt }) => {
    const existing = await findDay(ctx, userId, date);
    if (existing) {
      await ctx.db.patch(existing._id, { symptoms, symptomsLoggedAt: loggedAt });
      return existing._id;
    }
    return await ctx.db.insert("days", { userId, date, symptoms, symptomsLoggedAt: loggedAt, foods: [] });
  },
});
