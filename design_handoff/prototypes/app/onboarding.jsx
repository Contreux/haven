/* ============================================================
   HAVEN — ONBOARDING + PAYWALL  (flow component)
   Calm, clinical tone. Reuses Haven tokens / Icon set.
   ============================================================ */
const { useState: useOS, useEffect: useOE, useRef: useOR } = React;

/* tiny inline icons not in the shared set */
const Bell = () => <svg viewBox="0 0 24 24" fill="none"><path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6Z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round"/><path d="M10 19a2 2 0 0 0 4 0" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"/></svg>;

/* ---------- question config ---------- */
const Q = [
  { id: "frequency", kind: "single", layout: "list",
    kicker: "About you", title: "How often do migraines hit?", sub: "A rough average is fine — you can refine this later.",
    options: [
      { v: "rare", label: "Rarely — a few times a year" },
      { v: "1-3mo", label: "1–3 days a month" },
      { v: "weekly", label: "Around 1 day a week" },
      { v: "2-3wk", label: "2–3 days a week" },
      { v: "chronic", label: "Most days — it's constant" },
    ] },
  { id: "duration", kind: "single", layout: "list",
    kicker: "About you", title: "How long have you lived with them?",
    options: [
      { v: "lt1", label: "Less than a year" },
      { v: "1-3", label: "1 to 3 years" },
      { v: "3-10", label: "3 to 10 years" },
      { v: "gt10", label: "Over 10 years" },
      { v: "always", label: "As long as I can remember" },
    ] },
  { id: "age", kind: "single", layout: "list",
    kicker: "About you", title: "Your age range", sub: "Migraine patterns shift with age, so this helps us calibrate.",
    options: [
      { v: "u18", label: "Under 18" }, { v: "18-24", label: "18 – 24" },
      { v: "25-34", label: "25 – 34" }, { v: "35-44", label: "35 – 44" },
      { v: "45-54", label: "45 – 54" }, { v: "55+", label: "55 or older" },
    ] },
  { id: "sex", kind: "single", layout: "list",
    kicker: "About you", title: "Sex assigned at birth", sub: "Hormones are one of the most common drivers, so this matters clinically.",
    options: [
      { v: "female", label: "Female" }, { v: "male", label: "Male" },
      { v: "intersex", label: "Intersex" }, { v: "na", label: "Prefer not to say" },
    ] },
  { id: "cycle", kind: "single", layout: "list", requiresSex: ["female", "intersex"],
    kicker: "About you", title: "Do you track a menstrual cycle?", sub: "If so, Haven can line up attacks with your cycle to surface hormonal patterns.",
    options: [
      { v: "track", label: "Yes — I'd like to track it" },
      { v: "have", label: "I have a cycle, but won't track it" },
      { v: "no", label: "No, or not applicable" },
    ] },
  { id: "aura", kind: "single", layout: "list",
    kicker: "Your migraines", title: "Do you get aura?",
    sub: "Aura is warning signs 5–60 min before the pain: zig-zag or flashing vision, blind spots, pins-and-needles, or trouble finding words.",
    options: [
      { v: "often", label: "Yes, most of the time" },
      { v: "sometimes", label: "Sometimes" },
      { v: "no", label: "No, never" },
      { v: "unsure", label: "I'm not sure" },
    ] },
  { id: "symptoms", kind: "multi", layout: "grid",
    kicker: "Your migraines", title: "What comes with them?", sub: "Select everything you tend to feel during an attack.",
    options: [
      { v: "nausea", label: "Nausea", icon: "cup" },
      { v: "light", label: "Light sensitivity", icon: "sun" },
      { v: "sound", label: "Sound sensitivity", icon: "sound" },
      { v: "smell", label: "Smell sensitivity", icon: "wind" },
      { v: "vision", label: "Vision changes", icon: "eye" },
      { v: "neck", label: "Neck / shoulder pain", icon: "bone" },
      { v: "dizzy", label: "Dizziness", icon: "activity" },
      { v: "throb", label: "Throbbing pain", icon: "zap" },
    ] },
  { id: "severity", kind: "single", layout: "list",
    kicker: "Your migraines", title: "At their worst, how bad do they get?", sub: "Think about how much they stop your day.",
    options: [
      { v: "push", label: "I can push through it" },
      { v: "slow", label: "I have to slow right down" },
      { v: "liedown", label: "I need to lie down in the dark" },
      { v: "nofunction", label: "I can't function at all" },
    ] },
  { id: "triggers", kind: "multi", layout: "grid",
    kicker: "What you suspect", title: "What do you think sets yours off?",
    sub: "Pick any you suspect. Pinpointing these is exactly what Haven is for — so it's fine not to know.",
    options: [
      { v: "food", label: "Certain foods", icon: "utensils" },
      { v: "alcohol", label: "Alcohol", icon: "cup" },
      { v: "caffeine", label: "Caffeine", icon: "cup" },
      { v: "weather", label: "Weather changes", icon: "cloud" },
      { v: "stress", label: "Stress", icon: "zap" },
      { v: "sleep", label: "Poor sleep", icon: "moon" },
      { v: "dehydration", label: "Dehydration", icon: "droplet" },
      { v: "skipped", label: "Skipped meals", icon: "plate" },
    ],
    notSure: { v: "unsure", label: "I'm honestly not sure yet" } },
  { id: "meds", kind: "single", layout: "list",
    kicker: "Treatment", title: "How do you treat them now?", sub: "However you manage today is fine — there's no wrong answer.",
    options: [
      { v: "preventive", label: "Daily preventive medication" },
      { v: "rescue", label: "Rescue meds when one hits" },
      { v: "otc", label: "Over-the-counter only" },
      { v: "supplements", label: "Supplements or natural remedies" },
      { v: "nothing", label: "Nothing yet" },
    ] },
  { id: "goal", kind: "multi", layout: "list",
    kicker: "Your goal", title: "What would make Haven worth it?", sub: "We'll shape your home screen around this. Pick all that fit.",
    options: [
      { v: "triggers", label: "Pinpoint my triggers" },
      { v: "fewer", label: "Have fewer attacks" },
      { v: "doctor", label: "Prepare for a doctor's visit" },
      { v: "patterns", label: "Understand my patterns" },
      { v: "record", label: "Just keep a clear record" },
    ] },
];

const SYN_LINES = [
  "Mapping what you've told us…",
  "Checking your weather sensitivity…",
  "Lining up suspected triggers…",
  "Setting your tracking baseline…",
];

/* ---------- option renderers ---------- */
function ListOption({ opt, on, onClick }) {
  return (
    <button className={`ob-opt ${on ? "on" : ""}`} onClick={onClick}>
      {opt.icon && <span className="ico"><Icon name={opt.icon} /></span>}
      <span className="lab">{opt.label}</span>
      <span className="chk"><Icon name="check" /></span>
    </button>
  );
}
function GridChip({ opt, on, onClick, full }) {
  return (
    <button className={`ob-chip ${full ? "full" : ""} ${on ? "on" : ""}`} onClick={onClick}>
      {opt.icon && <Icon name={opt.icon} />}
      <span>{opt.label}</span>
    </button>
  );
}

/* ---------- question screen ---------- */
function QuestionScreen({ q, value, setValue, segNow, segTotal, onBack, onNext, canBack }) {
  const isMulti = q.kind === "multi";
  const arr = isMulti ? (value || []) : value;
  const sel = isMulti ? arr : value;
  const has = isMulti ? arr.length > 0 : !!value;

  const toggle = (v) => {
    if (!isMulti) { setValue(v); return; }
    const cur = value || [];
    setValue(cur.includes(v) ? cur.filter((x) => x !== v) : [...cur, v]);
  };

  return (
    <div className="ob">
      <StatusBar />
      <div className="ob-prog">
        <button className="ob-back" onClick={onBack} style={{ visibility: canBack ? "visible" : "hidden" }}><Icon name="chevL" /></button>
        <div className="ob-seg">{Array.from({ length: segTotal }).map((_, i) => <i key={i} className={i <= segNow ? "on" : ""} />)}</div>
        <div className="ob-step">{segNow + 1}/{segTotal}</div>
      </div>

      <div className="ob-scroll">
        <div className="ob-h">
          <div className="ob-kicker">{q.kicker}</div>
          <div className="ob-title">{q.title}</div>
          {q.sub && <div className="ob-sub">{q.sub}</div>}
        </div>

        {q.layout === "grid" ? (
          <div className="ob-grid">
            {q.options.map((o) => <GridChip key={o.v} opt={o} on={sel?.includes?.(o.v)} onClick={() => toggle(o.v)} />)}
            {q.notSure && <GridChip opt={q.notSure} full on={sel?.includes?.(q.notSure.v)} onClick={() => toggle(q.notSure.v)} />}
          </div>
        ) : (
          <div className="ob-opts">
            {q.options.map((o) => (
              <ListOption key={o.v} opt={o} on={isMulti ? sel?.includes?.(o.v) : value === o.v}
                onClick={() => toggle(o.v)} />
            ))}
          </div>
        )}
        <div style={{ height: 8 }} />
      </div>

      <div className="ob-foot">
        <button className="btn btn-primary ob-cta" disabled={!has} onClick={onNext}>
          Continue <Icon name="chevR" className="ar" />
        </button>
      </div>
    </div>
  );
}

/* ---------- welcome ---------- */
function Welcome({ onStart, onSignIn }) {
  return (
    <div className="ob">
      <StatusBar />
      <div className="ob-welcome">
        <div className="ob-mark"><Icon name="flame" style={{ width: 32, height: 32, fill: "var(--p-orange-ink)", stroke: "none" }} /></div>
        <div className="wbig">Find what's been triggering your migraines.</div>
        <div className="wsub">Haven turns your daily logs — meals, weather, sleep — into a clear, personal picture of what sets your attacks off.</div>
        <div className="wfoot">
          <button className="btn btn-primary ob-cta" onClick={onStart}>Get started <Icon name="chevR" className="ar" /></button>
          <button className="ob-skip" onClick={onSignIn}>I already have an account</button>
        </div>
      </div>
    </div>
  );
}

/* ---------- synthesis (analyzing → reveal) ---------- */
function buildProfile(a) {
  const auraYes = a.aura === "often" || a.aura === "sometimes";
  const chronic = a.frequency === "chronic" || a.frequency === "2-3wk";
  const klass = `${chronic ? "Chronic" : "Episodic"} migraine${auraYes ? " with aura" : ""}`;

  const TRIG = { food: "Food", alcohol: "Alcohol", caffeine: "Caffeine", weather: "Weather",
    stress: "Stress", sleep: "Sleep", dehydration: "Hydration", skipped: "Meal timing" };
  const picked = (a.triggers || []).filter((t) => t !== "unsure").map((t) => TRIG[t]).filter(Boolean);
  const chips = picked.length ? picked : ["To be discovered"];

  const watch = [
    { i: "cloud", b: "Barometric weather risk", s: "flagged before pressure swings" },
    { i: "utensils", b: "Meals & drinks", s: "scanned for common dietary triggers" },
    { i: "moon", b: "Sleep & stress", s: "tracked as the factors that stack up" },
  ];
  if (a.cycle === "track") watch.push({ i: "activity", b: "Hormonal cycle", s: "aligned with your attacks" });
  return { klass, chips, watch };
}

function Synthesis({ answers, onNext, onBack, start }) {
  const [phase, setPhase] = useOS(start || "load");
  const [line, setLine] = useOS(0);
  const prof = buildProfile(answers);

  useOE(() => {
    if (phase !== "load") return;
    const li = setInterval(() => setLine((n) => (n + 1) % SYN_LINES.length), 600);
    const to = setTimeout(() => { clearInterval(li); setPhase("reveal"); }, 2500);
    return () => { clearInterval(li); clearTimeout(to); };
  }, [phase]);

  if (phase === "load") {
    return (
      <div className="ob">
        <StatusBar />
        <div className="ob-syn">
          <div className="orb"><Icon name="loader" className="spin" /></div>
          <div className="stitle">Building your profile</div>
          <div className="sline">{SYN_LINES[line]}</div>
          <div className="sbar"><i /></div>
        </div>
      </div>
    );
  }
  return (
    <div className="ob">
      <StatusBar />
      <div className="ob-prog">
        <button className="ob-back" onClick={onBack}><Icon name="chevL" /></button>
        <div className="ob-seg">{Array.from({ length: 1 }).map((_, i) => <i key={i} className="on" />)}</div>
        <div className="ob-step" />
      </div>
      <div className="ob-scroll">
        <div className="ob-h">
          <div className="ob-kicker">Your starting point</div>
          <div className="ob-title">Here's what we'll build on.</div>
          <div className="ob-sub">Based on your answers — you can adjust any of this later.</div>
        </div>
        <div className="ob-card">
          <div className="clab">Your profile</div>
          <div className="cclass">{prof.klass}</div>
          <div className="cchips">
            <span className="chip-s" style={{ background: "rgba(239,106,32,.14)", color: "var(--color-accent)" }}>Suspected:</span>
            {prof.chips.map((c) => <span className="chip-s" key={c}>{c}</span>)}
          </div>
          <div className="ob-divide" />
          <div className="clab" style={{ marginBottom: 14 }}>What Haven will watch for you</div>
          <div className="ob-watch">
            {prof.watch.map((w) => (
              <div className="wrow" key={w.b}>
                <span className="wi"><Icon name="check" /></span>
                <span className="wt"><b>{w.b}</b> <span>— {w.s}</span></span>
              </div>
            ))}
          </div>
        </div>
        <div style={{ height: 8 }} />
      </div>
      <div className="ob-foot">
        <button className="btn btn-primary ob-cta" onClick={onNext}>Looks right <Icon name="chevR" className="ar" /></button>
      </div>
    </div>
  );
}

/* ---------- permission: weather ---------- */
function PermWeather({ onNext, onSkip, onBack }) {
  return (
    <div className="ob">
      <StatusBar />
      <div className="ob-prog">
        <button className="ob-back" onClick={onBack}><Icon name="chevL" /></button>
        <div className="ob-seg"><i className="on" /></div><div className="ob-step" />
      </div>
      <div className="ob-perm">
        <div className="ptile"><Icon name="cloud" /></div>
        <div className="ptitle">Let Haven watch the weather for you</div>
        <div className="pbody">A fast drop in <b>barometric pressure</b> is one of the most common migraine triggers. With your location, Haven warns you on high-risk days — before the attack.</div>
      </div>
      <div className="ob-foot">
        <button className="btn btn-primary ob-cta" onClick={onNext}><Icon name="pin" className="ar" /> Enable location</button>
        <button className="ob-skip" onClick={onSkip}>Not now</button>
      </div>
    </div>
  );
}

/* ---------- permission: reminders ---------- */
const TIMES = [
  { v: "morning", label: "Morning", t: "8:00 AM" },
  { v: "midday", label: "Midday", t: "12:30 PM" },
  { v: "evening", label: "Evening", t: "6:00 PM" },
  { v: "night", label: "Before bed", t: "9:30 PM" },
];
function PermReminders({ time, setTime, onNext, onSkip, onBack }) {
  return (
    <div className="ob">
      <StatusBar />
      <div className="ob-prog">
        <button className="ob-back" onClick={onBack}><Icon name="chevL" /></button>
        <div className="ob-seg"><i className="on" /></div><div className="ob-step" />
      </div>
      <div className="ob-perm">
        <div className="ptile"><Bell /></div>
        <div className="ptitle">One gentle nudge a day</div>
        <div className="pbody">Consistent logging is what makes the patterns show up. We'll send <b>one</b> quiet reminder — no spam. When suits you?</div>
        <div className="ob-times">
          {TIMES.map((t) => (
            <button key={t.v} className={`ob-time ${time === t.v ? "on" : ""}`} onClick={() => setTime(t.v)}>
              {t.label}<span className="tt">{t.t}</span>
            </button>
          ))}
        </div>
      </div>
      <div className="ob-foot">
        <button className="btn btn-primary ob-cta" onClick={onNext}>Turn on reminders</button>
        <button className="ob-skip" onClick={onSkip}>Maybe later</button>
      </div>
    </div>
  );
}

/* ---------- paywall ---------- */
const PAY_FEATS = [
  { i: "sparkle", t: "AI trigger analysis on every meal you log" },
  { i: "cloud", t: "Barometric weather-risk forecasts" },
  { i: "book", t: "Unlimited history & doctor-ready reports" },
  { i: "trend", t: "Personal pattern insights that sharpen over time" },
];
function Paywall({ plan, setPlan, onSubscribe, onClose }) {
  const yearly = plan === "yearly";
  return (
    <div className="ob">
      <StatusBar />
      <div className="ob-pay">
        <button className="ob-payx" onClick={onClose}><Icon name="x" /></button>
        <div className="ob-pay-scroll">
          <div className="phead">
            <div className="pmark"><Icon name="flame" style={{ fill: "var(--p-orange-ink)", stroke: "none", width: 27, height: 27 }} /></div>
            <div className="ptitle">Start finding your triggers</div>
            <div className="psub">Your profile's ready. Unlock the tools that turn daily logs into real answers.</div>
          </div>

          <div className="ob-feats">
            {PAY_FEATS.map((f) => (
              <div className="ob-feat" key={f.t}>
                <span className="fi"><Icon name={f.i} /></span>
                <span className="ft">{f.t}</span>
              </div>
            ))}
          </div>

          <div className="ob-plans">
            <button className={`ob-plan ${yearly ? "on" : ""}`} onClick={() => setPlan("yearly")}>
              <span className="ob-badge">SAVE 87% · 7 DAYS FREE</span>
              <span className="pradio" />
              <span className="pm">
                <span className="pn">Yearly</span>
                <span className="pmeta">$83.20 billed once a year</span>
              </span>
              <span className="pp"><span className="pw">$1.60</span><span className="pu">per week</span></span>
            </button>
            <button className={`ob-plan ${!yearly ? "on" : ""}`} onClick={() => setPlan("weekly")}>
              <span className="pradio" />
              <span className="pm">
                <span className="pn">Weekly</span>
                <span className="pmeta">Billed every week</span>
              </span>
              <span className="pp"><span className="pw">$12</span><span className="pu">per week</span></span>
            </button>
          </div>
        </div>

        <div className="ob-pay-foot">
          <button className="btn btn-primary ob-cta" onClick={onSubscribe}>
            {yearly ? "Start 7-day free trial" : "Subscribe weekly"}
          </button>
          <div className="ob-fine">
            {yearly
              ? "7 days free, then $83.20/year ($1.60/week). Cancel anytime."
              : "$12 per week. Cancel anytime."}
          </div>
          <div className="ob-links">
            <button onClick={onClose}>Restore</button>
            <button onClick={onClose}>Terms</button>
            <button onClick={onClose}>Privacy</button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- done ---------- */
function Done({ trial, onEnter }) {
  return (
    <div className="ob">
      <StatusBar />
      <div className="ob-done">
        <div className="dmark"><Icon name="check" /></div>
        <div className="dtitle">You're all set</div>
        <div className="dsub">{trial
          ? "Your 7-day free trial is live. Let's log your first day and start building the picture."
          : "Your profile's saved. Let's log your first day and start building the picture."}</div>
        <div style={{ height: 30 }} />
        <button className="btn btn-primary ob-cta" style={{ maxWidth: 280 }} onClick={onEnter}>Enter Haven</button>
      </div>
    </div>
  );
}

window.Onboarding = { Q, Welcome, QuestionScreen, Synthesis, PermWeather, PermReminders, Paywall, Done, buildProfile };
