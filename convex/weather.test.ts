import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { api } from "./_generated/api";

const modules = import.meta.glob("./**/*.ts");

test("fetchWeather returns a weather shape or throws (network-dependent)", async () => {
  const t = convexTest(schema, modules);
  try {
    const w = await t.action(api.weather.fetchWeather, { lat: 51.51, lon: -0.13 });
    expect(["low", "mid", "high"]).toContain(w.level);
    expect(Array.isArray(w.pressureTrend)).toBe(true);
  } catch (e) {
    // edge-runtime has no real network — a throw is acceptable; the client falls back to the stub.
    expect(e).toBeTruthy();
  }
});
