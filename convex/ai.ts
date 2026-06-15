"use node";
import { action } from "./_generated/server";
import { v } from "convex/values";

const LEVELS: Record<string, "low" | "mid" | "high"> = {
  high: "high", medium: "mid", mid: "mid", low: "low",
};

const PROMPT = (desc: string) =>
  `You are a migraine dietary-trigger assistant. A user ate/drank: "${desc}".
Identify likely migraine food triggers present. Common ones: aged cheese (tyramine), cured/processed meats (nitrates), chocolate, caffeine, alcohol (esp. red wine), MSG, aspartame, citrus, fermented foods, nuts, soy sauce, tomatoes.
Reply with ONLY valid minified JSON, no markdown, exactly this shape:
{"label":"short meal name","triggers":[{"name":"Aged cheese","level":"high","reason":"short reason under 8 words"}],"note":"one short calm sentence"}
Rank triggers high→low. level is "high","medium" or "low". If none, use [].`;

export const analyzeFood = action({
  args: { description: v.string() },
  handler: async (_ctx, { description }) => {
    const key = process.env.ANTHROPIC_API_KEY;
    if (!key) throw new Error("ANTHROPIC_API_KEY not configured");

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 512,
        messages: [{ role: "user", content: PROMPT(description) }],
      }),
    });
    if (!res.ok) throw new Error(`Anthropic error ${res.status}`);
    const data = await res.json();
    const text: string = data?.content?.[0]?.text ?? "";
    const clean = text.replace(/```json|```/g, "").trim();
    const parsed = JSON.parse(clean); // throws on bad shape → client falls back

    const triggers = (Array.isArray(parsed.triggers) ? parsed.triggers : []).map((t: any) => ({
      label: String(t.name ?? t.label ?? "Trigger"),
      level: LEVELS[String(t.level).toLowerCase()] ?? "low",
      reason: String(t.reason ?? ""),
    }));
    return {
      label: String(parsed.label ?? description).slice(0, 42),
      triggers,
      note: String(parsed.note ?? ""),
    };
  },
});
