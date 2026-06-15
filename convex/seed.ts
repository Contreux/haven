import { mutation } from "./_generated/server";
import { v } from "convex/values";

// DEV-ONLY fixture. Deletes + re-seeds ~6 weeks for a device, so it must NOT be
// exposed in production (it would wipe real user data). Add a deployment guard
// before any real-user launch (M5). Safe on the dev deployment.

const DAYS = 45;

function minusDays(date: string, n: number): string {
  const d = new Date(date + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() - n);
  return d.toISOString().slice(0, 10);
}

// Deterministic PRNG so the same device+date always generates the same day.
function rng(seedStr: string): () => number {
  let h = 1779033703 ^ seedStr.length;
  for (let i = 0; i < seedStr.length; i++) {
    h = Math.imul(h ^ seedStr.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = h >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

type Trig = { label: string; level: "low" | "mid" | "high"; reason: string };
type Meal = { name: string; time: string; triggers: Trig[] };

const TRIGGER_MEALS: Meal[] = [
  { name: "Aged cheddar toastie", time: "12:30", triggers: [{ label: "Aged cheese", level: "high", reason: "High in tyramine" }] },
  { name: "Red wine", time: "20:10", triggers: [{ label: "Alcohol", level: "high", reason: "Tannins + histamines" }] },
  { name: "Pepperoni pizza", time: "19:20", triggers: [{ label: "Cured meat", level: "high", reason: "Contains nitrates" }] },
  { name: "Soy-glazed ramen", time: "19:00", triggers: [{ label: "MSG", level: "high", reason: "Flavor enhancer" }, { label: "Soy sauce", level: "mid", reason: "High-tyramine condiment" }] },
  { name: "Brie & crackers", time: "16:40", triggers: [{ label: "Aged cheese", level: "high", reason: "Brie is high in tyramine" }] },
  { name: "Dark chocolate", time: "15:30", triggers: [{ label: "Chocolate", level: "mid", reason: "Caffeine + phenylethylamine" }] },
  { name: "Cold brew", time: "07:45", triggers: [{ label: "Caffeine", level: "mid", reason: "Excess or withdrawal can trigger" }] },
  { name: "Oat-milk latte", time: "08:15", triggers: [{ label: "Caffeine", level: "mid", reason: "Excess or withdrawal can trigger" }] },
  { name: "Diet soda", time: "14:00", triggers: [{ label: "Artificial sweetener", level: "mid", reason: "Aspartame sensitivity" }] },
  { name: "Deli salami sandwich", time: "12:45", triggers: [{ label: "Cured meat", level: "high", reason: "Nitrates" }, { label: "Aged cheese", level: "mid", reason: "Provolone" }] },
];
const CLEAN_MEALS: Meal[] = [
  { name: "Greek yogurt & berries", time: "08:30", triggers: [] },
  { name: "Grilled chicken salad", time: "13:00", triggers: [] },
  { name: "Banana oatmeal", time: "08:00", triggers: [] },
  { name: "Veg stir-fry & rice", time: "19:10", triggers: [] },
  { name: "Toast & scrambled eggs", time: "09:00", triggers: [] },
  { name: "Apple & almond butter", time: "16:00", triggers: [] },
  { name: "Salmon & greens", time: "19:30", triggers: [] },
  { name: "Lentil soup", time: "12:30", triggers: [] },
];
const SYMPTOM_POOL = ["nausea", "aura", "light", "sound", "neck", "dizzy"];
const LEVEL_W: Record<string, number> = { high: 3, mid: 2, low: 1 };
const pick = <T,>(r: number, arr: T[]): T => arr[Math.floor(r * arr.length) % arr.length];

function genDay(userId: string, date: string, forceMigraine: boolean) {
  const r = rng(userId + ":" + date);
  // ~12% of days are gaps (nothing logged) — realistic.
  if (!forceMigraine && r() < 0.12) {
    return { userId, date, symptoms: [], foods: [] as Meal[] };
  }

  const sleepHours = Math.round((4.5 + r() * 4.5) * 2) / 2; // 4.5–9h
  const stress: "low" | "mid" | "high" = r() < 0.4 ? "low" : r() < 0.75 ? "mid" : "high";
  const hydration: "low" | "mid" | "high" = r() < 0.45 ? "mid" : r() < 0.75 ? "low" : "high";
  const weatherSensitive = r() < 0.6;
  const factorsLoggedAt = "09:0" + Math.floor(r() * 9);

  // Build the day's meals: 1–3, mixing clean + trigger foods.
  const meals: Meal[] = [];
  const nMeals = 1 + Math.floor(r() * 3);
  for (let i = 0; i < nMeals; i++) {
    meals.push(r() < (forceMigraine ? 0.7 : 0.4) ? pick(r(), TRIGGER_MEALS) : pick(r(), CLEAN_MEALS));
  }
  meals.sort((a, b) => a.time.localeCompare(b.time));

  // Risk score → migraine likelihood (creates real correlations for Insights).
  const triggerLoad = meals.reduce((s, m) => s + m.triggers.reduce((t, x) => t + (LEVEL_W[x.level] ?? 0), 0), 0);
  let risk = triggerLoad
    + (sleepHours < 6 ? 2 : 0)
    + (stress === "high" ? 2 : 0)
    + (hydration === "low" ? 1 : 0)
    + (weatherSensitive ? r() * 2 : 0);
  const hadMigraine = forceMigraine || (risk >= 5 && r() < risk / 12);

  let migraine: { had: boolean; severity: string; time: string; notes: string } | undefined;
  let symptoms: string[] = [];
  let symptomsLoggedAt: string | undefined;
  if (hadMigraine) {
    const sev = risk >= 8 ? "severe" : risk >= 5 ? "moderate" : "mild";
    const mTime = `${14 + Math.floor(r() * 6)}:${String(Math.floor(r() * 6) * 10).padStart(2, "0")}`;
    migraine = { had: true, severity: sev, time: mTime, notes: weatherSensitive ? "Pressure was dropping" : "Built through the afternoon" };
    const nSym = 1 + Math.floor(r() * 3);
    const used = new Set<string>();
    for (let i = 0; i < nSym; i++) { const s = pick(r(), SYMPTOM_POOL); if (!used.has(s)) { used.add(s); symptoms.push(s); } }
    symptomsLoggedAt = migraine.time;
  }

  return {
    userId, date,
    factors: { sleepHours, stress, hydration, weatherSensitive },
    factorsLoggedAt,
    ...(migraine ? { migraine } : {}),
    symptoms,
    ...(symptomsLoggedAt ? { symptomsLoggedAt } : {}),
    foods: meals.map((m) => ({ name: m.name, time: m.time, triggers: m.triggers })),
  };
}

export const seed = mutation({
  args: { userId: v.string(), today: v.string() },
  handler: async (ctx, { userId, today }) => {
    // Production guard: this fixture DELETES a date range before inserting, so it must
    // never run against real user data. It is allowed only when explicitly enabled
    // (`npx convex env set ALLOW_SEED true` on dev) or under the test runner. Prod
    // deployments leave ALLOW_SEED unset, so this throws.
    if (process.env.ALLOW_SEED !== "true" && process.env.NODE_ENV !== "test") {
      throw new Error("seed is disabled: set ALLOW_SEED=true on non-production deployments to use it");
    }

    const dates = Array.from({ length: DAYS }, (_, i) => minusDays(today, i));

    // Idempotent: clear existing rows for the range first.
    for (const date of dates) {
      const rows = await ctx.db
        .query("days")
        .withIndex("by_user_date", (q) => q.eq("userId", userId).eq("date", date))
        .collect();
      for (const row of rows) await ctx.db.delete(row._id);
    }

    for (const date of dates) {
      // Today is a fully-populated showcase day (migraine + symptoms + foods).
      await ctx.db.insert("days", genDay(userId, date, date === today));
    }

    return dates.length;
  },
});
