import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

const level = v.union(v.literal("low"), v.literal("mid"), v.literal("high"));

const triggerChip = v.object({
  label: v.string(),
  level: level,
});

const foodEntry = v.object({
  name: v.string(),
  time: v.string(), // "HH:mm"
  triggers: v.array(triggerChip),
});

export default defineSchema({
  days: defineTable({
    userId: v.string(),
    date: v.string(), // "YYYY-MM-DD"
    factors: v.optional(
      v.object({
        sleepHours: v.number(),
        stress: level,
        hydration: level,
        weatherSensitive: v.boolean(),
      }),
    ),
    factorsLoggedAt: v.optional(v.string()), // "HH:mm"
    migraine: v.optional(
      v.object({
        had: v.boolean(),
        severity: v.string(),
        time: v.string(),
        notes: v.string(),
      }),
    ),
    symptoms: v.array(v.string()),
    symptomsLoggedAt: v.optional(v.string()),
    foods: v.array(foodEntry),
  }).index("by_user_date", ["userId", "date"]),

  settings: defineTable({
    userId: v.string(),
    theme: v.string(),
  }).index("by_user", ["userId"]),
});
