/* ============================================================
   HAVEN — DATA LAYER
   localStorage persistence, seed data, mock weather, food analysis
   (real Claude with a keyword engine as fallback).
   ============================================================ */

/* ---------- date helpers ---------- */
const pad = (n) => String(n).padStart(2, "0");
const keyOf = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const todayKey = () => keyOf(new Date());
const prettyDate = (d) =>
  d.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" });
const nowTime = () =>
  new Date().toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
const MONTHS = ["January","February","March","April","May","June","July","August","September","October","November","December"];
const DOW = ["S","M","T","W","T","F","S"];
const LEVEL_ORDER = { high: 0, medium: 1, low: 2 };

/* ---------- storage (localStorage) ---------- */
const LKEY = "haven:logs:v1";
function loadLogs() {
  try { const r = localStorage.getItem(LKEY); return r ? JSON.parse(r) : null; }
  catch { return null; }
}
function saveLogs(logs) {
  try { localStorage.setItem(LKEY, JSON.stringify(logs)); }
  catch (e) { console.warn("save failed", e); }
}
function clearLogs() { try { localStorage.removeItem(LKEY); } catch {} }

/* ---------- seed data (so the app feels lived-in) ---------- */
function seedData() {
  const out = {};
  const mk = (offset, entry) => {
    const d = new Date(); d.setDate(d.getDate() - offset);
    out[keyOf(d)] = entry;
  };
  // today
  mk(0, {
    foods: [
      { id: "t1", label: "Cold brew", time: "7:40 AM", note: "Large, oat milk",
        triggers: [{ name: "Caffeine", level: "medium", reason: "Excess or withdrawal can trigger" }] },
      { id: "t2", label: "Aged cheddar toastie", time: "12:15 PM", note: "Sourdough, sharp cheddar",
        triggers: [{ name: "Aged cheese", level: "high", reason: "High in tyramine" },
                   { name: "Yeast (bread)", level: "low", reason: "Yeast-containing foods" }] },
    ],
    migraine: { had: false },
    factors: { sleep: 7.5, stress: "Medium", hydration: "Low", weatherSensitive: true },
  });
  mk(1, {
    foods: [
      { id: "s1", label: "Aged cheddar & crackers", time: "1:10 PM",
        triggers: [{ name: "Aged cheese", level: "high", reason: "High in tyramine" }] },
      { id: "s2", label: "Red wine", time: "8:20 PM",
        triggers: [{ name: "Red wine", level: "high", reason: "Tannins + histamines" }] },
    ],
    migraine: { had: true, severity: "Moderate", time: "9:40 PM", notes: "Started behind the eyes" },
    symptoms: ["light", "eye"],
    factors: { sleep: 5.5, stress: "High", hydration: "Low", weatherSensitive: true },
  });
  mk(2, {
    foods: [{ id: "s3", label: "Oatmeal & banana", time: "8:00 AM", triggers: [] }],
    migraine: { had: false },
    factors: { sleep: 8, stress: "Low", hydration: "Medium" },
  });
  mk(3, {
    foods: [
      { id: "s4", label: "Deli sandwich (salami)", time: "12:30 PM",
        triggers: [{ name: "Cured meat", level: "high", reason: "Contains nitrates" },
                   { name: "Aged cheese", level: "medium", reason: "Provolone" }] },
      { id: "s5", label: "Dark chocolate", time: "3:00 PM",
        triggers: [{ name: "Chocolate", level: "medium", reason: "Caffeine + phenylethylamine" }] },
    ],
    migraine: { had: false },
    factors: { sleep: 7, stress: "Medium", hydration: "Medium" },
  });
  mk(5, {
    foods: [{ id: "s6", label: "Soy-glazed ramen", time: "7:10 PM",
      triggers: [{ name: "MSG", level: "high", reason: "Flavor enhancer" },
                 { name: "Soy sauce", level: "medium", reason: "High-tyramine condiment" }] }],
    migraine: { had: true, severity: "Severe", time: "10:30 PM", notes: "Throbbing, light-sensitive" },
    symptoms: ["light", "nausea", "sound"],
    factors: { sleep: 6, stress: "High", hydration: "Low", weatherSensitive: false },
  });
  mk(6, {
    foods: [{ id: "s7", label: "Grilled chicken salad", time: "1:00 PM", triggers: [] }],
    migraine: { had: false },
    factors: { sleep: 8.5, stress: "Low", hydration: "High" },
  });
  mk(8, {
    foods: [{ id: "s8", label: "Brie & grapes", time: "4:00 PM",
      triggers: [{ name: "Aged cheese", level: "high", reason: "Brie is high in tyramine" }] }],
    migraine: { had: true, severity: "Mild", time: "6:00 PM" },
    symptoms: ["neck"],
    factors: { sleep: 6.5, stress: "Medium", hydration: "Medium" },
  });
  return out;
}

/* ---------- mock weather + risk read ---------- */
/* deterministic per-day so it doesn't jump around on re-render */
function mockWeather() {
  // today's reading — tuned to "Elevated" to match the Haven hero
  const swing = 8;        // hPa pressure swing
  const tempSwing = 9;    // °
  const humidity = 71;
  const temp = 17;
  const trend = [1015.6, 1014.9, 1013.2, 1011.5, 1010.1, 1009.4, 1008.8, 1007.6]; // falling
  let level = "Low", lvlClass = "lvl-low", bars = 1;
  if (swing >= 8) { level = "Elevated"; lvlClass = "lvl-high"; bars = 3; }
  else if (swing >= 4) { level = "Moderate"; lvlClass = "lvl-mid"; bars = 2; }
  return {
    level, lvlClass, bars, swing, tempSwing, humidity, temp, trend,
    headline: `Pressure dropping ${swing} hPa`,
    detail: `with a ${tempSwing}° swing — your two strongest signals are both active.`,
  };
}

/* ---------- keyword trigger engine (offline, always works) ---------- */
function fallbackAnalyze(text) {
  const t = (text || "").toLowerCase();
  const rules = [
    [/cheese|cheddar|parmesan|brie|blue|gouda|gruy|provolone/, "Aged cheese", "high", "High in tyramine"],
    [/wine|beer|alcohol|cocktail|whiskey|prosecco|champagne|spirit/, "Alcohol", "high", "Common vasodilator trigger"],
    [/salami|pepperoni|bacon|hot dog|deli|cured|sausage|ham|prosciutto|nitrate/, "Cured meat", "high", "Contains nitrates"],
    [/msg|flavou?r enhancer|bouillon|stock cube/, "MSG", "high", "Flavor enhancer"],
    [/soy sauce|tamari|fish sauce|miso/, "Soy sauce", "medium", "High-tyramine condiment"],
    [/chocolate|cocoa|cacao/, "Chocolate", "medium", "Caffeine + phenylethylamine"],
    [/coffee|espresso|caffeine|energy drink|cola|matcha|cold brew/, "Caffeine", "medium", "Excess or withdrawal can trigger"],
    [/diet|aspartame|sweetener|sugar.?free|zero/, "Artificial sweetener", "medium", "Aspartame sensitivity"],
    [/citrus|orange|lemon|lime|grapefruit/, "Citrus", "low", "Reported sensitivity in some"],
    [/onion|garlic|pickle|kimchi|sauerkraut|fermented|yogurt|sourdough|yeast/, "Fermented / yeast", "low", "Histamine + tyramine content"],
    [/nut|almond|peanut|walnut|pecan|cashew/, "Nuts", "low", "Possible trigger"],
    [/tomato|marinara|ketchup|salsa/, "Tomato", "low", "Tomato-based foods"],
  ];
  const triggers = [];
  for (const [re, name, level, reason] of rules)
    if (re.test(t) && !triggers.find((x) => x.name === name)) triggers.push({ name, level, reason });
  triggers.sort((a, b) => LEVEL_ORDER[a.level] - LEVEL_ORDER[b.level]);
  const label = text ? text.replace(/\s+/g, " ").trim().slice(0, 42) : "Food";
  return {
    label: label.charAt(0).toUpperCase() + label.slice(1),
    triggers,
    note: triggers.length ? "Estimated locally from your description." : "No obvious dietary triggers spotted.",
  };
}

/* ---------- real Claude analysis with graceful fallback ---------- */
const ANALYSIS_PROMPT = (desc) =>
`You are a migraine dietary-trigger assistant. A user ate/drank: "${desc}".
Identify likely migraine food triggers present. Common ones: aged cheese (tyramine), cured/processed meats (nitrates), chocolate, caffeine, alcohol (esp. red wine), MSG, aspartame, citrus, fermented foods, nuts, soy sauce, tomatoes.
Reply with ONLY valid minified JSON, no markdown, exactly this shape:
{"label":"short meal name","triggers":[{"name":"Aged cheese","level":"high","reason":"short reason under 8 words"}],"note":"one short calm sentence"}
Rank triggers high→low by strength. level is "high","medium" or "low". If none, use [].`;

async function analyzeFood(desc) {
  const safe = (desc || "").trim();
  // try real model; fall back to keyword engine on any hiccup
  try {
    if (window.claude && typeof window.claude.complete === "function") {
      const raw = await window.claude.complete(ANALYSIS_PROMPT(safe));
      const clean = raw.replace(/```json|```/g, "").trim();
      const parsed = JSON.parse(clean);
      if (parsed && Array.isArray(parsed.triggers)) {
        parsed.triggers.sort((a, b) => (LEVEL_ORDER[a.level] ?? 3) - (LEVEL_ORDER[b.level] ?? 3));
        if (!parsed.label) parsed.label = fallbackAnalyze(safe).label;
        return parsed;
      }
    }
  } catch (e) { /* fall through */ }
  // realistic minimum think-time so the fallback still feels considered
  return fallbackAnalyze(safe);
}

/* ---------- shared option sets ---------- */
const SYMPTOMS = [
  { k: "light", label: "Light / glare", icon: "sun" },
  { k: "eye", label: "Eye strain", icon: "eye" },
  { k: "neck", label: "Neck pain", icon: "bone" },
  { k: "back", label: "Back pain", icon: "activity" },
  { k: "nausea", label: "Nausea", icon: "alert" },
  { k: "sound", label: "Sound sensitivity", icon: "sound" },
];
const LMH = ["Low", "Medium", "High"];

Object.assign(window, {
  pad, keyOf, todayKey, prettyDate, nowTime, MONTHS, DOW, LEVEL_ORDER,
  loadLogs, saveLogs, clearLogs, seedData, mockWeather,
  fallbackAnalyze, analyzeFood, SYMPTOMS, LMH,
});
