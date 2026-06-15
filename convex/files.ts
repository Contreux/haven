import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => await ctx.storage.generateUploadUrl(),
});

export const getImageUrl = query({
  args: { imageId: v.string() },
  handler: async (ctx, { imageId }) => {
    try {
      return await ctx.storage.getUrl(imageId as any);
    } catch {
      return null;
    }
  },
});
