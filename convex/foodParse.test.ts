import { expect, test } from "vitest";
import { parseAnalysis } from "./foodParse";

test("parses itemized JSON with triggers", () => {
  const r = parseAnalysis('{"label":"Burger","items":["Cheeseburger","Fries"],"triggers":[{"name":"Aged cheese","level":"high","reason":"tyramine"}],"note":"ok"}', "fallback");
  expect(r.items).toEqual(["Cheeseburger", "Fries"]);
  expect(r.triggers[0]).toEqual({ label: "Aged cheese", level: "high", reason: "tyramine" });
  expect(r.label).toBe("Burger");
});
test("strips markdown fences and normalizes medium->mid", () => {
  const r = parseAnalysis('```json\n{"label":"x","items":[],"triggers":[{"name":"Caffeine","level":"medium","reason":"r"}],"note":""}\n```', "fb");
  expect(r.triggers[0].level).toBe("mid");
});
test("missing items -> [] and empty triggers ok", () => {
  const r = parseAnalysis('{"label":"x","triggers":[],"note":""}', "fb");
  expect(r.items).toEqual([]);
  expect(r.triggers).toEqual([]);
});
test("falls back to provided label when absent", () => {
  const r = parseAnalysis('{"triggers":[],"note":""}', "My hint");
  expect(r.label).toBe("My hint");
});
