import { mutation } from "./_generated/server";
import { v } from "convex/values";

// DEV-ONLY fixture. Deletes + re-seeds up to 4 days for a device, so it must NOT
// be exposed in production (it would wipe real user data). Add a deployment guard
// before any real-user launch (M5). Safe on the M1 dev deployment.

// Subtract `n` days from a "YYYY-MM-DD" string, returning the same format.
function minusDays(date: string, n: number): string {
  const d = new Date(date + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() - n);
  return d.toISOString().slice(0, 10);
}

export const seed = mutation({
  args: { userId: v.string(), today: v.string() },
  handler: async (ctx, { userId, today }) => {
    const dates = [today, minusDays(today, 1), minusDays(today, 2), minusDays(today, 3)];

    // Clear any existing rows for these dates so re-seeding is idempotent.
    for (const date of dates) {
      const rows = await ctx.db
        .query("days")
        .withIndex("by_user_date", (q) => q.eq("userId", userId).eq("date", date))
        .collect();
      for (const row of rows) await ctx.db.delete(row._id);
    }

    // Today — full, lively day (drives the ledger + the migraine alert + summary).
    await ctx.db.insert("days", {
      userId,
      date: dates[0],
      factors: { sleepHours: 6.5, stress: "high", hydration: "low", weatherSensitive: true },
      factorsLoggedAt: "09:02",
      migraine: { had: true, severity: "moderate", time: "15:10", notes: "Behind the left eye" },
      symptoms: ["nausea", "aura"],
      symptomsLoggedAt: "14:40",
      foods: [
        { name: "Oat latte", time: "08:15", triggers: [] },
        { name: "Aged cheddar", time: "12:30", triggers: [{ label: "Tyramine", level: "high" }] },
        { name: "Dark chocolate", time: "16:05", triggers: [{ label: "Caffeine", level: "mid" }] },
      ],
    });

    // Yesterday — calm day, no migraine.
    await ctx.db.insert("days", {
      userId,
      date: dates[1],
      factors: { sleepHours: 8, stress: "low", hydration: "mid", weatherSensitive: true },
      factorsLoggedAt: "08:30",
      symptoms: [],
      symptomsLoggedAt: undefined,
      foods: [{ name: "Greek yogurt", time: "09:00", triggers: [] }],
    });

    // Two days ago — a migraine day.
    await ctx.db.insert("days", {
      userId,
      date: dates[2],
      factors: { sleepHours: 5.5, stress: "mid", hydration: "low", weatherSensitive: true },
      factorsLoggedAt: "10:10",
      migraine: { had: true, severity: "severe", time: "18:40", notes: "Storm front" },
      symptoms: ["light sensitivity"],
      symptomsLoggedAt: "18:00",
      foods: [{ name: "Red wine", time: "19:30", triggers: [{ label: "Histamine", level: "high" }] }],
    });

    // Three days ago — minimal entry (keeps the streak going).
    await ctx.db.insert("days", {
      userId,
      date: dates[3],
      symptoms: [],
      foods: [{ name: "Toast", time: "08:00", triggers: [] }],
    });

    return dates.length;
  },
});
