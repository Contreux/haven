"use node";
import { action } from "./_generated/server";
import { v } from "convex/values";

export const fetchWeather = action({
  args: { lat: v.number(), lon: v.number() },
  handler: async (_ctx, { lat, lon }) => {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
      `&hourly=surface_pressure,temperature_2m,relative_humidity_2m,wind_speed_10m&forecast_days=1`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Open-Meteo ${res.status}`);
    const data = await res.json();
    const h = data?.hourly;
    if (!h || !Array.isArray(h.surface_pressure)) throw new Error("bad weather shape");

    const press: number[] = h.surface_pressure.slice(0, 8);
    const temps: number[] = h.temperature_2m.slice(0, 8);
    const swing = Math.round(Math.max(...press) - Math.min(...press));
    const tempSwing = Math.round(Math.max(...temps) - Math.min(...temps));
    const temp = Math.round(temps[0]);
    const humidity = Math.round(h.relative_humidity_2m?.[0] ?? 0);
    const falling = press[press.length - 1] < press[0];
    const trend = Math.abs(press[press.length - 1] - press[0]) < 1 ? "steady" : (falling ? "falling" : "rising");

    let level: "low" | "mid" | "high" = "low", bars = 1, headline = "Calm pressure";
    if (swing >= 8) { level = "high"; bars = 3; headline = `Pressure dropping ${swing} hPa`; }
    else if (swing >= 4) { level = "mid"; bars = 2; headline = "Shifting front"; }
    const detail = swing >= 4
      ? `with a ${tempSwing}° swing — your strongest signals are active.`
      : `Stable pressure with a ${tempSwing}° temp swing — low trigger risk.`;

    return { level, bars, swing, tempSwing, humidity, temp, trend, headline, detail,
             pressureTrend: press.map((p) => Math.round(p * 10) / 10) };
  },
});
