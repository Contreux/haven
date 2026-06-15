const VERDICTS: Record<string, "safe" | "caution" | "avoid"> = {
  safe: "safe", ok: "safe", good: "safe", low: "safe",
  caution: "caution", warn: "caution", warning: "caution", mid: "caution", medium: "caution", maybe: "caution",
  avoid: "avoid", high: "avoid", danger: "avoid", bad: "avoid",
};

export function parseMenuAnalysis(text: string, fallbackName: string) {
  const clean = text.replace(/```json|```/g, "").trim();
  const parsed = JSON.parse(clean);
  const raw = Array.isArray(parsed.dishes) ? parsed.dishes : [];
  const dishes = raw
    .slice(0, 30)
    .map((d: any) => {
      const triggers = (Array.isArray(d.triggers) ? d.triggers : [])
        .map((x: any) => String(x))
        .filter((s: string) => s.length > 0);
      return {
        name: String(d.name ?? fallbackName).slice(0, 48),
        verdict: VERDICTS[String(d.verdict).toLowerCase()] ?? "caution",
        triggers,
        reason: String(d.reason ?? "").slice(0, 60),
      };
    })
    .filter((d: any) => d.name.length > 0);
  return { dishes };
}
