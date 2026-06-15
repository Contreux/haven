export const LEVELS: Record<string, "low" | "mid" | "high"> = {
  high: "high", medium: "mid", mid: "mid", low: "low",
};

export function parseAnalysis(text: string, fallbackLabel: string) {
  const clean = text.replace(/```json|```/g, "").trim();
  const parsed = JSON.parse(clean);
  const triggers = (Array.isArray(parsed.triggers) ? parsed.triggers : []).map((t: any) => ({
    label: String(t.name ?? t.label ?? "Trigger"),
    level: LEVELS[String(t.level).toLowerCase()] ?? "low",
    reason: String(t.reason ?? ""),
  }));
  const items = (Array.isArray(parsed.items) ? parsed.items : [])
    .map((x: any) => String(x)).filter((s: string) => s.length > 0);
  return {
    label: String(parsed.label ?? fallbackLabel).slice(0, 42),
    items,
    triggers,
    note: String(parsed.note ?? ""),
  };
}
