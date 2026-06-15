import { describe, it, expect } from "vitest";
import { parseMenuAnalysis } from "./menuParse";

describe("parseMenuAnalysis", () => {
  it("parses dishes and keeps triggers", () => {
    const text =
      '{"dishes":[{"name":"Margherita Pizza","verdict":"avoid","triggers":["aged cheese","tomato"],"reason":"tyramine and tomato"},{"name":"Garden Salad","verdict":"safe","triggers":[],"reason":""}]}';
    const r = parseMenuAnalysis(text, "Dish");
    expect(r.dishes).toHaveLength(2);
    expect(r.dishes[0].verdict).toBe("avoid");
    expect(r.dishes[0].triggers).toEqual(["aged cheese", "tomato"]);
    expect(r.dishes[1].verdict).toBe("safe");
  });

  it("strips code fences and maps verdict synonyms", () => {
    const text = '```json\n{"dishes":[{"name":"X","verdict":"high"},{"name":"Y","verdict":"warn"}]}\n```';
    const r = parseMenuAnalysis(text, "Dish");
    expect(r.dishes[0].verdict).toBe("avoid");
    expect(r.dishes[1].verdict).toBe("caution");
  });

  it("defaults unknown verdict to caution and drops empty names", () => {
    const text = '{"dishes":[{"name":"","verdict":"safe"},{"name":"Z","verdict":"???"}]}';
    const r = parseMenuAnalysis(text, "Dish");
    expect(r.dishes).toHaveLength(1);
    expect(r.dishes[0].name).toBe("Z");
    expect(r.dishes[0].verdict).toBe("caution");
  });

  it("caps dishes at 30 and clamps long fields", () => {
    const many = Array.from({ length: 40 }, (_, i) => ({ name: "D" + i, verdict: "safe" }));
    const r = parseMenuAnalysis(JSON.stringify({ dishes: many }), "Dish");
    expect(r.dishes).toHaveLength(30);
  });
});
