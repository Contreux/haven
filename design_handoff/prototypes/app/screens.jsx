/* ============================================================
   HAVEN — SCREENS  (Today, Calendar, Insights, Weather)
   + shared atoms (StatusBar, TopBar, RiskHero, FoodCard…)
   ============================================================ */
const { useState } = React;

/* ---------- status bar ---------- */
function StatusBar() {
  return (
    <div className="sb">
      <span>9:41</span>
      <div className="r">
        <svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="7" width="3" height="5" rx="1" fill="currentColor"/><rect x="4.5" y="4.5" width="3" height="7.5" rx="1" fill="currentColor"/><rect x="9" y="2" width="3" height="10" rx="1" fill="currentColor"/><rect x="13.5" y="0" width="3" height="12" rx="1" fill="currentColor" opacity="0.35"/></svg>
        <svg width="17" height="12" viewBox="0 0 17 12" fill="none"><path d="M8.5 2.5c2.2 0 4.2.8 5.7 2.2M8.5 5.4c1.4 0 2.7.5 3.7 1.4M8.5 8.2c.6 0 1.2.2 1.6.7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/></svg>
        <svg width="26" height="13" viewBox="0 0 26 13"><rect x="0.6" y="0.6" width="21" height="11.8" rx="3" fill="none" stroke="currentColor" strokeOpacity="0.4"/><rect x="2.2" y="2.2" width="16" height="8.6" rx="1.6" fill="currentColor"/><rect x="23" y="4" width="2" height="5" rx="1" fill="currentColor" opacity="0.4"/></svg>
      </div>
    </div>
  );
}

/* ---------- header ---------- */
function TopBar({ title, date, streak }) {
  return (
    <div className="head">
      <div>
        <div className="title">{title}</div>
        {date && <div className="date">{date}</div>}
      </div>
      <div className="tools">
        {streak != null && (
          <div className="iconbtn streak">
            <svg className="fl" viewBox="0 0 18 22"><path d="M9 1.5c2.6 3 4.4 4.8 4.4 8.2A4.4 4.4 0 0 1 9 14.6c-1 0-1.9-.6-1.9-1.7 0-1.3 1.2-1.9 1.2-3.6 0 0-2.4 1.2-2.4 4.3 0 1.1.4 2 .4 2A6 6 0 0 1 3 10.4C3 6.3 6.6 4.7 9 1.5Z" fill="var(--color-accent)"/></svg>
            <b>{streak}</b>
          </div>
        )}
        <div className="iconbtn"><Icon name="search" /></div>
        <div className="iconbtn"><Icon name="user" /></div>
      </div>
    </div>
  );
}

/* ---------- weather-risk hero ---------- */
function RiskHero({ weather, onTap }) {
  const bars = [0, 1, 2, 3].map((i) => (
    <i key={i} className={i < weather.bars ? "on" : ""} />
  ));
  return (
    <div className={`risk tap ${weather.lvlClass}`} onClick={onTap}>
      <div className="lab">Weather risk today</div>
      <div className="row">
        <div className="word">{weather.level}</div>
        <div className="gauge">{bars}</div>
      </div>
      <div className="meta"><b>{weather.headline}</b> {weather.detail}</div>
    </div>
  );
}

/* ---------- factor rings ---------- */
function ringFor(kind, factors) {
  if (!factors) return null;
  if (kind === "sleep") {
    const h = factors.sleep ?? null; if (h == null) return null;
    const cls = h >= 7 ? "good" : h >= 5.5 ? "mid" : "high";
    return { cls, pct: Math.min(100, Math.round((h / 9) * 100)), val: `${h}h`, lab: "Sleep" };
  }
  if (kind === "stress") {
    const s = factors.stress; if (!s) return null;
    const cls = s === "Low" ? "good" : s === "Medium" ? "mid" : "high";
    const pct = s === "Low" ? 34 : s === "Medium" ? 60 : 90;
    return { cls, pct, val: s === "Medium" ? "Med" : s, lab: "Stress" };
  }
  if (kind === "water") {
    const w = factors.hydration; if (!w) return null;
    const cls = w === "High" ? "good" : w === "Medium" ? "mid" : "high";
    const pct = w === "High" ? 90 : w === "Medium" ? 60 : 34;
    return { cls, pct, val: w === "Medium" ? "Med" : w, lab: "Water" };
  }
  return null;
}
function FactorRings({ factors, onEdit }) {
  const items = ["sleep", "stress", "water"].map((k) => ringFor(k, factors));
  return (
    <>
      <div className="slabel"><div className="t">Today's factors</div>
        <div className="a" style={{ cursor: "pointer" }} onClick={onEdit}>Edit</div></div>
      <div className="rings" onClick={onEdit} style={{ cursor: "pointer" }}>
        {items.map((it, i) => (
          <div className="rc" key={i}>
            {it ? (
              <>
                <div className={`ring ${it.cls}`} style={{ "--p": it.pct + "%" }}><i>{it.val}</i></div>
                <div className="lab">{it.lab}</div>
              </>
            ) : (
              <>
                <div className="ring" style={{ "--rc": "var(--color-track)", "--p": "0%" }}><i>–</i></div>
                <div className="lab">{["Sleep", "Stress", "Water"][i]}</div>
              </>
            )}
          </div>
        ))}
      </div>
    </>
  );
}

/* ---------- trigger chip ---------- */
function TriggerChip({ t }) {
  return (
    <div className="trig">
      <span className={`dot ${t.level}`} />
      <span className="nm">{t.name}</span>
      <span className="lv">{t.level}</span>
    </div>
  );
}

/* ---------- food card ---------- */
function FoodCard({ f, onDelete }) {
  return (
    <div className="food">
      <div className="food-head">
        {f.thumb
          ? <img className="food-thumb" src={f.thumb} alt="" />
          : <div className="food-thumb"><Icon name="utensils" /></div>}
        <div className="food-main">
          <div className="food-top">
            <div className="food-name">{f.label}</div>
            <div className="food-time">{f.time}</div>
          </div>
          {f.note && <div className="food-note">{f.note}</div>}
        </div>
        {onDelete && (
          <button className="food-del" onClick={onDelete} aria-label="Delete"><Icon name="trash" /></button>
        )}
      </div>
      {f.triggers && f.triggers.length > 0 ? (
        <div className="food-trigs">{f.triggers.map((t, i) => <TriggerChip key={i} t={t} />)}</div>
      ) : (
        <div className="food-clean"><Icon name="check" /> No obvious triggers</div>
      )}
    </div>
  );
}

/* ---------- symptom + factor summary ---------- */
function SummaryCard({ day }) {
  const syms = day?.symptoms || [];
  const f = day?.factors;
  if (syms.length === 0 && !f) return null;
  const factxt = f && [
    f.sleep != null ? `Sleep ${f.sleep}h` : null,
    f.stress ? `Stress ${f.stress.toLowerCase()}` : null,
    f.hydration ? `Water ${f.hydration.toLowerCase()}` : null,
    f.weatherSensitive ? "Felt weather-sensitive" : null,
  ].filter(Boolean).join("  ·  ");
  return (
    <div className="summary">
      {syms.length > 0 && (
        <div style={{ marginBottom: f ? 13 : 0 }}>
          <div className="lab">Symptoms</div>
          <div className="chiprow">
            {syms.map((s) => (
              <span className="chip-s" key={s}>{SYMPTOMS.find((x) => x.k === s)?.label || s}</span>
            ))}
          </div>
        </div>
      )}
      {f && (
        <div>
          <div className="lab">Daily factors</div>
          <div className="factxt">{factxt}</div>
        </div>
      )}
    </div>
  );
}

/* ============================================================ */
/* TODAY                                                         */
/* ============================================================ */
function TodayScreen({ day, weather, streak, onWeather, onFactors, onMigraine, onFood, onDeleteFood }) {
  const foods = day?.foods || [];
  const migraine = day?.migraine;
  return (
    <div className="body">
      <TopBar title="Today" date={prettyDate(new Date())} streak={streak} />
      <RiskHero weather={weather} onTap={onWeather} />
      <FactorRings factors={day?.factors} onEdit={onFactors} />

      <div className="actions">
        <button className="btn btn-primary" onClick={onMigraine}><Icon name="plus" className="ar" /> Log a migraine</button>
        <button className="btn btn-ghost" onClick={onFood}>Snap a meal</button>
      </div>

      {migraine?.had && (
        <div className="alert-card danger">
          <Icon name="alert" />
          <span className="t">Migraine today</span>
          <span className="m">{migraine.severity} · {migraine.time}</span>
        </div>
      )}

      <SummaryCard day={day} />

      <div className="slabel"><div className="t">Logged today</div>
        <div className="a">{foods.length} {foods.length === 1 ? "item" : "items"}</div></div>
      {foods.length === 0 ? (
        <div className="empty">
          <div className="big">No food logged yet</div>
          <div className="sub">Snap a photo or describe a meal. Every entry builds your trigger picture over time.</div>
        </div>
      ) : (
        foods.map((f) => <FoodCard key={f.id} f={f} onDelete={() => onDeleteFood(f.id)} />)
      )}
      <div style={{ height: 18 }} />
    </div>
  );
}

/* ============================================================ */
/* CALENDAR                                                      */
/* ============================================================ */
function CalendarScreen({ logs, onOpenDay }) {
  const [cursor, setCursor] = useState(new Date());
  const y = cursor.getFullYear(), m = cursor.getMonth();
  const first = new Date(y, m, 1).getDay();
  const days = new Date(y, m + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < first; i++) cells.push(null);
  for (let d = 1; d <= days; d++) cells.push(d);
  const sevColor = (sev) => sev === "Severe" ? "var(--color-factor-high)" : sev === "Mild" ? "var(--color-factor-mid)" : "var(--color-accent)";

  return (
    <div className="body">
      <TopBar title="Calendar" />
      <div className="cal-bar">
        <button className="cal-arrow" onClick={() => setCursor(new Date(y, m - 1, 1))}><Icon name="chevL" /></button>
        <div className="cal-month">{MONTHS[m]} <span>{y}</span></div>
        <button className="cal-arrow" onClick={() => setCursor(new Date(y, m + 1, 1))}><Icon name="chevR" /></button>
      </div>
      <div className="dow">{DOW.map((d, i) => <span key={i}>{d}</span>)}</div>
      <div className="cal-grid">
        {cells.map((d, i) => {
          if (!d) return <div key={i} className="cell empty" />;
          const dk = keyOf(new Date(y, m, d));
          const log = logs[dk];
          const isToday = dk === todayKey();
          const had = log?.migraine?.had;
          const fc = log?.foods?.length || 0;
          const hasSym = (log?.symptoms?.length || 0) > 0;
          return (
            <button key={i} className={`cell ${isToday ? "today" : ""}`} onClick={() => onOpenDay(dk)}>
              <span className="d">{d}</span>
              <span className={`mark ${had ? "mig" : ""}`} style={had ? { "--mc": sevColor(log.migraine.severity) } : null}>
                {fc > 0 && <span className="fdot" />}
                {fc === 0 && hasSym && <span className="sdot" />}
              </span>
            </button>
          );
        })}
      </div>
      <div className="legend">
        <span className="li"><span className="ring" /> Migraine (ring = severity)</span>
        <span className="li"><span className="fdot" /> Food logged</span>
        <span className="li"><span className="sdot" /> Symptoms</span>
      </div>
      <div style={{ height: 12 }} />
    </div>
  );
}

/* ============================================================ */
/* INSIGHTS                                                      */
/* ============================================================ */
function InsightsScreen({ logs }) {
  const counts = {};
  let migDays = 0, trackedDays = 0;
  Object.values(logs).forEach((day) => {
    if (day.migraine?.had) migDays++;
    if (day.foods?.length || day.factors || day.symptoms?.length) trackedDays++;
    const had = day.migraine?.had;
    (day.foods || []).forEach((f) => (f.triggers || []).forEach((t) => {
      if (!counts[t.name]) counts[t.name] = { name: t.name, total: 0, onMig: 0, level: t.level };
      counts[t.name].total++;
      if (had) counts[t.name].onMig++;
    }));
  });
  const ranked = Object.values(counts).sort((a, b) => (b.onMig - a.onMig) || (b.total - a.total));
  const maxTotal = Math.max(1, ...ranked.map((r) => r.total));

  return (
    <div className="body">
      <TopBar title="Insights" />
      <div className="statrow">
        <div className="bigstat"><div className="v ink-high">{migDays}</div><div className="k">Migraine days</div></div>
        <div className="bigstat"><div className="v" style={{ color: "var(--color-ink)" }}>{trackedDays}</div><div className="k">Days tracked</div></div>
        <div className="bigstat"><div className="v" style={{ color: "var(--color-accent)" }}>{ranked.length}</div><div className="k">Triggers seen</div></div>
      </div>

      <div className="slabel"><div className="t">Your triggers</div></div>
      <div className="muted" style={{ margin: "-8px 2px 16px", fontSize: "var(--text-base)" }}>
        Ranked by how often they land on a migraine day.
      </div>

      {ranked.length === 0 ? (
        <div className="empty"><div className="sub">Log a few meals to start building your trigger ranking.</div></div>
      ) : (
        ranked.map((r, i) => (
          <div className="trank" key={r.name}>
            <span className="rk">{i + 1}</span>
            <div className="body2">
              <div className="top">
                <span className="nm">{r.name}</span>
                <span className={`ct ink-${r.onMig > 0 ? "high" : "low"}`}>
                  {r.onMig > 0 ? `${r.onMig} migraine${r.onMig === 1 ? "" : "s"}` : "no overlap"}
                </span>
              </div>
              <div className="bar"><i className={`fill ${r.level}`} style={{ width: `${(r.total / maxTotal) * 100}%` }} /></div>
              <div className="sub">Eaten {r.total} time{r.total === 1 ? "" : "s"}</div>
            </div>
          </div>
        ))
      )}

      <div className="note-card">
        <div className="h"><Icon name="sparkle" /> A note on patterns</div>
        <p>This is a list of <b>hypotheses to test</b>, not conclusions. Triggers stack — a food often only sets things off alongside poor sleep, stress or dehydration. Look for patterns over weeks, not single days.</p>
      </div>
      <div style={{ height: 16 }} />
    </div>
  );
}

/* ============================================================ */
/* WEATHER                                                       */
/* ============================================================ */
function WeatherScreen({ weather }) {
  const maxT = Math.max(...weather.trend), minT = Math.min(...weather.trend);
  const spark = weather.trend.map((p, i) => {
    const h = 8 + ((p - minT) / (maxT - minT || 1)) * 30;
    return <i key={i} className={i >= weather.trend.length - 3 ? "hi" : ""} style={{ height: h }} />;
  });
  return (
    <div className="body">
      <TopBar title="Weather" />
      <RiskHero weather={weather} onTap={() => {}} />

      <div className="wx-grid">
        <div className="wx-cell">
          <div className="k"><Icon name="gauge" /> Pressure swing</div>
          <div className="v">{weather.swing} <small>hPa</small></div>
          <div className="t">Falling — strongest signal</div>
          <div className="spark">{spark}</div>
        </div>
        <div className="wx-cell">
          <div className="k"><Icon name="thermo" /> Temp swing</div>
          <div className="v">{weather.tempSwing}<small>°</small></div>
          <div className="t">Now {weather.temp}° · second signal</div>
          <div className="spark">
            <i style={{ height: 14 }} /><i style={{ height: 22 }} /><i className="hi" style={{ height: 34 }} /><i className="hi" style={{ height: 26 }} /><i style={{ height: 18 }} /><i style={{ height: 12 }} /><i style={{ height: 20 }} /><i style={{ height: 28 }} />
          </div>
        </div>
        <div className="wx-cell">
          <div className="k"><Icon name="droplet" /> Humidity</div>
          <div className="v">{weather.humidity}<small>%</small></div>
          <div className="t">Logged, not led on</div>
        </div>
        <div className="wx-cell">
          <div className="k"><Icon name="wind" /> Wind</div>
          <div className="v">11 <small>mph</small></div>
          <div className="t">Light · gusts later</div>
        </div>
      </div>

      <div className="note-card">
        <div className="h"><Icon name="cloud" /> Why this matters</div>
        <p><b>Pressure and temperature</b> are the strongest recurring weather signals in the research. When barometric pressure drops quickly, the change can set off attacks in sensitive people. Humidity looks more individual and seasonal, so Haven logs it but doesn't lead with it.</p>
      </div>
      <div style={{ height: 16 }} />
    </div>
  );
}

Object.assign(window, {
  StatusBar, TopBar, RiskHero, FactorRings, TriggerChip, FoodCard, SummaryCard,
  TodayScreen, CalendarScreen, InsightsScreen, WeatherScreen,
});
