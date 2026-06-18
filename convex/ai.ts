"use node";
import { action } from "./_generated/server";
import { v } from "convex/values";
import { parseAnalysis } from "./foodParse";
import { parseMenuAnalysis } from "./menuParse";

const TRIGGERS_GUIDE =
  "Common migraine triggers: aged cheese (tyramine), cured/processed meats (nitrates), chocolate, caffeine, alcohol (esp. red wine), MSG, aspartame, citrus, fermented foods, nuts, soy sauce, tomatoes.";

const MENU_ANNOTATE_PROMPT = `I'm uploading a restaurant menu image. Please analyse the menu and return an annotated version of the same image showing which dishes may contain common migraine triggers.

Task:

1. Read the menu image carefully.
2. Extract all visible menu sections and menu items.
3. For each dish, infer the likely ingredients from the dish name and common culinary usage.
4. Identify any dishes that may contain common migraine-trigger ingredients.
5. Create an edited version of the original menu image with colour-coded highlights and small badges explaining the likely trigger.

Important:

* Use the uploaded menu image as the direct edit target.
* Preserve the original menu layout, typography, colours, branding, prices, and text.
* Do not redesign the menu.
* Do not rewrite or distort the menu text.
* Keep all menu text readable.
* Do not cross items out unless I specifically ask for that.
* Use subtle translucent highlights behind flagged items.
* Add small rounded badges beside flagged items explaining why they may be a trigger.
* Use at most 1-2 badges per menu item so the image stays clean.
* If a trigger is only inferred, mark it conservatively and avoid overclaiming.
* Do not flag an item unless the menu wording gives a reasonable basis for it.

Badge colour system:

* Red badge: CURED MEAT
* Orange badge: AGED CHEESE
* Teal badge: FERMENTED / PICKLED
* Purple badge: SMOKED / CURED
* Pink badge: HISTAMINE
* Yellow badge: CITRUS
* Brown badge: CHOCOLATE
* Burgundy badge: ALCOHOL / WINE
* Blue badge: SEAFOOD
* Grey badge: UNCLEAR / ASK STAFF

Add a small legend at the bottom or in an open area of the menu:
"Potential migraine triggers vary by person. Ask staff for ingredients if unsure."

The final output should be a clean annotated menu image that looks polished, easy to read, and useful for quickly deciding what to avoid.`;

const JSON_SHAPE =
  `Reply with ONLY valid minified JSON, no markdown, exactly this shape:\n` +
  `{"label":"short meal name","items":["each distinct food or drink"],"triggers":[{"name":"Aged cheese","level":"high","reason":"short reason under 8 words"}],"note":"one short calm sentence"}\n` +
  `Rank triggers high→low. level is "high","medium" or "low". If none, use [].`;

async function callClaude(content: any, maxTokens = 512): Promise<string> {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not configured");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({ model: "claude-haiku-4-5-20251001", max_tokens: maxTokens, messages: [{ role: "user", content }] }),
  });
  if (!res.ok) throw new Error(`Anthropic error ${res.status}`);
  const data = await res.json();
  return data?.content?.[0]?.text ?? "";
}

export function firstImageBase64(resp: any): string | null {
  const b64 = resp?.data?.[0]?.b64_json;
  return typeof b64 === "string" && b64.length > 0 ? b64 : null;
}

async function callOpenAIImageEdit(imageBase64: string, prompt: string): Promise<string | null> {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error("OPENAI_API_KEY not configured");
  const form = new FormData();
  form.append("model", "gpt-image-1");
  form.append("prompt", prompt);
  form.append("quality", "high");
  form.append("n", "1");
  form.append("image", new Blob([Buffer.from(imageBase64, "base64")], { type: "image/jpeg" }), "menu.jpg");
  const res = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}` },
    body: form,
  });
  if (!res.ok) throw new Error(`OpenAI error ${res.status}`);
  return firstImageBase64(await res.json());
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

export const scanMenu = action({
  args: { imageBase64: v.string(), suspected: v.optional(v.array(v.string())) },
  handler: async (ctx, { imageBase64, suspected }) => {
    const safeSuspected = (suspected ?? []).slice(0, 8).map((s) => s.slice(0, 24));
    const focus =
      safeSuspected.length > 0
        ? `\n\nThe user especially suspects these trigger categories: ${safeSuspected.join(", ")}. Weight those higher when in doubt.`
        : ``;

    // Annotated image (OpenAI) + structured fallback list (Claude), in parallel.
    const [annotatedUrl, dishes] = await Promise.all([
      annotateMenuImage(ctx, imageBase64, MENU_ANNOTATE_PROMPT + focus).catch((e) => {
        console.error("menu annotate failed:", e);
        return null;
      }),
      classifyMenuDishes(imageBase64, safeSuspected).catch((e) => {
        console.error("menu classify failed:", e);
        return [];
      }),
    ]);
    return { annotatedUrl: annotatedUrl ?? undefined, dishes };
  },
});

async function annotateMenuImage(ctx: any, imageBase64: string, prompt: string): Promise<string | null> {
  const b64 = await callOpenAIImageEdit(imageBase64, prompt);
  if (!b64) return null;
  const blob = new Blob([Buffer.from(b64, "base64")], { type: "image/png" });
  const storageId = await ctx.storage.store(blob);
  return await ctx.storage.getUrl(storageId);
}

async function classifyMenuDishes(imageBase64: string, safeSuspected: string[]) {
  const focus =
    safeSuspected.length > 0
      ? `The user especially suspects these trigger categories: ${safeSuspected.join(", ")}. Weight those higher when in doubt.\n`
      : ``;
  const text =
    `This is a photo of a restaurant menu. List each distinct dish you can read. ` +
    `For each dish, classify it for a migraine sufferer as safe, caution, or avoid using these triggers: ${TRIGGERS_GUIDE}\n` +
    focus +
    `Reply with ONLY minified JSON, no markdown, exactly this shape:\n` +
    `{"dishes":[{"name":"dish name","verdict":"safe|caution|avoid","triggers":["aged cheese"],"reason":"short reason under 8 words"}]}\n` +
    `If a dish has no likely trigger use verdict "safe" and triggers [].`;
  const content = [
    { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
    { type: "text", text },
  ];
  return parseMenuAnalysis(await callClaude(content, 1500), "Dish").dishes;
}
