"use node";
import { action } from "./_generated/server";
import { v } from "convex/values";
import { parseAnalysis } from "./foodParse";

const TRIGGERS_GUIDE =
  "Common migraine triggers: aged cheese (tyramine), cured/processed meats (nitrates), chocolate, caffeine, alcohol (esp. red wine), MSG, aspartame, citrus, fermented foods, nuts, soy sauce, tomatoes.";

const JSON_SHAPE =
  `Reply with ONLY valid minified JSON, no markdown, exactly this shape:\n` +
  `{"label":"short meal name","items":["each distinct food or drink"],"triggers":[{"name":"Aged cheese","level":"high","reason":"short reason under 8 words"}],"note":"one short calm sentence"}\n` +
  `Rank triggers high→low. level is "high","medium" or "low". If none, use [].`;

async function callClaude(content: any): Promise<string> {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not configured");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({ model: "claude-haiku-4-5-20251001", max_tokens: 512, messages: [{ role: "user", content }] }),
  });
  if (!res.ok) throw new Error(`Anthropic error ${res.status}`);
  const data = await res.json();
  return data?.content?.[0]?.text ?? "";
}

export const analyzeFood = action({
  args: { description: v.string() },
  handler: async (_ctx, { description }) => {
    const prompt = `You are a migraine dietary-trigger assistant. A user ate/drank: "${description}".\n` +
      `Identify likely migraine food triggers present. ${TRIGGERS_GUIDE}\n${JSON_SHAPE}`;
    return parseAnalysis(await callClaude(prompt), description);
  },
});

export const analyzeFoodImage = action({
  args: { imageBase64: v.string(), hint: v.optional(v.string()) },
  handler: async (_ctx, { imageBase64, hint }) => {
    const text = `You are a migraine dietary-trigger assistant analyzing a PHOTO of food/drink.\n` +
      `Identify each distinct food or drink item visible, then likely migraine triggers present. ${TRIGGERS_GUIDE}\n` +
      (hint && hint.length > 0 ? `The user adds: "${hint}".\n` : ``) +
      JSON_SHAPE;
    const content = [
      { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
      { type: "text", text },
    ];
    return parseAnalysis(await callClaude(content), hint && hint.length > 0 ? hint : "Meal photo");
  },
});
