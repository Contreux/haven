import { mutation, query, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { menuDishValidator } from "./schema";

// Kick off an async menu scan: create a pending row, schedule the heavy action, return the id.
// The client subscribes to getMenuScan(id) and waits for status to leave "pending".
export const startMenuScan = mutation({
  args: { imageBase64: v.string(), suspected: v.optional(v.array(v.string())) },
  handler: async (ctx, { imageBase64, suspected }) => {
    const scanId = await ctx.db.insert("menuScans", { status: "pending", dishes: [] });
    await ctx.scheduler.runAfter(0, internal.ai.runMenuScan, {
      scanId,
      imageBase64,
      suspected: suspected ?? [],
    });
    return scanId;
  },
});

// Subscribed by the client; emits again when the scheduled action patches the row.
export const getMenuScan = query({
  args: { id: v.id("menuScans") },
  handler: async (ctx, { id }) => {
    const row = await ctx.db.get(id);
    if (!row) return { status: "error", dishes: [] };
    return { status: row.status, annotatedUrl: row.annotatedUrl, dishes: row.dishes };
  },
});

// Written by the scheduled action (internal.ai.runMenuScan) when the scan finishes.
export const finishMenuScan = internalMutation({
  args: {
    scanId: v.id("menuScans"),
    status: v.string(),
    annotatedUrl: v.optional(v.string()),
    dishes: v.array(menuDishValidator),
  },
  handler: async (ctx, { scanId, status, annotatedUrl, dishes }) => {
    await ctx.db.patch(scanId, { status, annotatedUrl, dishes });
  },
});
