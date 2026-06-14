/* ============================================================
   HAVEN — SHEETS & NAV
   Bottom-sheet wrapper, Migraine / Symptom / Factors sheets,
   Day detail, dark Log-Food capture, bottom nav + speed dial.
   ============================================================ */
const { useState: useS, useRef, useEffect: useFx } = React;

/* ---------- bottom-sheet wrapper ---------- */
function Sheet({ children, onClose }) {
  return (
    <div className="scrim" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        <div className="grab" />
        {children}
      </div>
    </div>
  );
}

/* ---------- segmented control ---------- */
function Segmented({ options, value, onChange }) {
  return (
    <div className="seg">
      {options.map((o) => (
        <button key={o} className={value === o ? "on" : ""} onClick={() => onChange(o)}>{o}</button>
      ))}
    </div>
  );
}

/* ---------- Log Migraine ---------- */
function MigraineSheet({ existing, onClose, onSave, onRemove }) {
  const [severity, setSeverity] = useS(existing?.severity || "Moderate");
  const [notes, setNotes] = useS(existing?.notes || "");
  return (
    <Sheet onClose={onClose}>
      <div className="sheet-title">Log a migraine</div>
      <div className="sheet-sub">{prettyDate(new Date())}</div>

      <div className="field-label">Severity</div>
      <Segmented options={["Mild", "Moderate", "Severe"]} value={severity} onChange={setSeverity} />

      <div className="field-label">Notes</div>
      <textarea className="ta" value={notes} onChange={(e) => setNotes(e.target.value)}
        placeholder="Onset, location, what preceded it…" />

      <button className="btn btn-primary btn-block"
        onClick={() => onSave({ had: true, severity, time: nowTime(), notes })}>
        <Icon name="check" className="ar" /> Save
      </button>
      {existing?.had && (
        <button className="btn btn-danger btn-block" style={{ marginTop: 10 }} onClick={onRemove}>
          Remove migraine
        </button>
      )}
    </Sheet>
  );
}

/* ---------- Log Symptoms ---------- */
function SymptomSheet({ existing, onClose, onSave }) {
  const [sel, setSel] = useS(existing || []);
  const toggle = (k) => setSel((s) => (s.includes(k) ? s.filter((x) => x !== k) : [...s, k]));
  return (
    <Sheet onClose={onClose}>
      <div className="sheet-title">Log symptoms</div>
      <div className="sheet-sub">{prettyDate(new Date())}</div>
      <div className="symgrid" style={{ marginTop: 20 }}>
        {SYMPTOMS.map((s) => (
          <button key={s.k} className={`symbtn ${sel.includes(s.k) ? "on" : ""}`} onClick={() => toggle(s.k)}>
            <Icon name={s.icon} /> {s.label}
          </button>
        ))}
      </div>
      <button className="btn btn-primary btn-block" onClick={() => onSave(sel)}>
        <Icon name="check" className="ar" /> Save
      </button>
    </Sheet>
  );
}

/* ---------- Daily Factors ---------- */
function FactorsSheet({ existing, onClose, onSave }) {
  const [sleep, setSleep] = useS(existing?.sleep ?? 7);
  const [stress, setStress] = useS(existing?.stress || "Medium");
  const [hydration, setHydration] = useS(existing?.hydration || "Medium");
  const [ws, setWs] = useS(existing?.weatherSensitive || false);
  return (
    <Sheet onClose={onClose}>
      <div className="sheet-title">Daily factors</div>
      <div className="sheet-sub">Often more predictive than food alone.</div>

      <div className="field-label">Sleep</div>
      <div className="slider-row">
        <input type="range" min="0" max="12" step="0.5" value={sleep}
          onChange={(e) => setSleep(parseFloat(e.target.value))} />
        <span className="val">{sleep}h</span>
      </div>

      <div className="field-label">Stress</div>
      <Segmented options={LMH} value={stress} onChange={setStress} />

      <div className="field-label">Hydration</div>
      <Segmented options={LMH} value={hydration} onChange={setHydration} />

      <button className="switch-row" onClick={() => setWs((v) => !v)}>
        <span className="t">I felt weather-sensitive today</span>
        <span className={`switch ${ws ? "on" : ""}`}><i /></span>
      </button>

      <button className="btn btn-primary btn-block"
        onClick={() => onSave({ sleep, stress, hydration, weatherSensitive: ws })}>
        <Icon name="check" className="ar" /> Save
      </button>
    </Sheet>
  );
}

/* ---------- Day detail (from calendar) ---------- */
function DayDetail({ dk, log, onClose }) {
  const d = new Date(dk + "T00:00:00");
  const foods = log?.foods || [];
  return (
    <Sheet onClose={onClose}>
      <div className="sheet-title">{prettyDate(d)}</div>
      {log?.migraine?.had && (
        <div className="alert-card danger" style={{ marginTop: 16 }}>
          <Icon name="alert" />
          <span className="t">Migraine</span>
          <span className="m">{log.migraine.severity} · {log.migraine.time}</span>
        </div>
      )}
      {log?.migraine?.notes && <div className="muted" style={{ margin: "2px 2px 6px", fontSize: "var(--text-base)" }}>{log.migraine.notes}</div>}

      <div className="field-label" style={{ marginTop: 18 }}>Food</div>
      {foods.length === 0
        ? <div className="muted" style={{ fontSize: "var(--text-base)", padding: "2px 2px 6px" }}>Nothing logged.</div>
        : foods.map((f) => <FoodCard key={f.id} f={f} />)}

      <SummaryCard day={log} />
      <div style={{ height: 6 }} />
    </Sheet>
  );
}

/* ---------- Log Food (dark capture) ---------- */
const SAMPLE_MEALS = [
  "Aged cheddar toastie on sourdough",
  "Glass of red wine",
  "Pepperoni pizza",
  "Oatmeal with banana",
  "Dark chocolate square",
  "Soy-glazed ramen",
];
function downscale(dataUrl, max = 180) {
  return new Promise((res) => {
    const img = new Image();
    img.onload = () => {
      const s = Math.min(1, max / Math.max(img.width, img.height));
      const cv = document.createElement("canvas");
      cv.width = Math.round(img.width * s); cv.height = Math.round(img.height * s);
      cv.getContext("2d").drawImage(img, 0, 0, cv.width, cv.height);
      res(cv.toDataURL("image/jpeg", 0.65));
    };
    img.onerror = () => res(null);
    img.src = dataUrl;
  });
}

function LogFoodCapture({ onClose, onSave, demo }) {
  const [mode, setMode] = useS(demo?.mode || "photo");
  const [preview, setPreview] = useS(demo?.preview || null);
  const [desc, setDesc] = useS(demo?.desc || "");        // describe-mode text
  const [photoDesc, setPhotoDesc] = useS(demo?.photoDesc || ""); // inferred desc for photo mode
  const [busy, setBusy] = useS(false);
  const [result, setResult] = useS(demo?.result || null);
  const fileRef = useRef(null);

  const onFile = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const r = new FileReader();
    r.onload = () => { setPreview(r.result); setPhotoDesc(file.name.replace(/\.[a-z]+$/i, "").replace(/[-_]/g, " ")); };
    r.readAsDataURL(file);
  };

  const canAnalyze = mode === "photo" ? (preview || photoDesc) : desc.trim().length > 1;

  const run = async () => {
    setBusy(true);
    const text = mode === "photo" ? (photoDesc || "the meal in the photo") : desc;
    const t0 = Date.now();
    let r;
    try { r = await analyzeFood(text); } catch { r = fallbackAnalyze(text); }
    const wait = Math.max(0, 900 - (Date.now() - t0)); // keep the "thinking" beat
    setTimeout(() => { setResult(r); setBusy(false); }, wait);
  };

  const save = async () => {
    const thumb = preview ? await downscale(preview) : null;
    onSave({
      id: Math.random().toString(36).slice(2),
      label: result.label || "Food",
      time: nowTime(),
      note: result.note || "",
      triggers: result.triggers || [],
      thumb,
    });
  };

  return (
    <div className="capture theme-dark">
      <div className="cap-head">
        <div>
          <div className="t">Log food</div>
          <div className="s">{prettyDate(new Date())}</div>
        </div>
        <button className="cap-x" onClick={onClose}><Icon name="x" /></button>
      </div>

      {!result && (
        <>
          <div className="cap-stage">
            {preview ? <img src={preview} alt="" />
              : mode === "photo"
                ? <div className="hint"><Icon name="camera" /><div>Add a photo of your meal</div></div>
                : <textarea value={desc} onChange={(e) => setDesc(e.target.value)} placeholder="Describe what you ate or drank…" autoFocus />}
          </div>

          {mode === "photo" && !preview && (
            <div className="samples">
              {SAMPLE_MEALS.map((s) => (
                <button key={s} className="sample" onClick={() => { setPhotoDesc(s); }}>
                  {photoDesc === s ? "✓ " : ""}{s}
                </button>
              ))}
            </div>
          )}
          {mode === "photo" && photoDesc && !preview && (
            <div className="muted" style={{ marginTop: 12, fontSize: "var(--text-base)" }}>Selected: <b style={{ color: "var(--color-ink)" }}>{photoDesc}</b></div>
          )}

          <input ref={fileRef} type="file" accept="image/*" capture="environment" onChange={onFile} style={{ display: "none" }} />

          <div className="cap-modes">
            <button className={`sample ${mode === "photo" ? "" : ""}`} style={mode === "photo" ? { background: "var(--color-surface)", color: "var(--color-ink)" } : null} onClick={() => setMode("photo")}><Icon name="camera" style={{ width: 15, height: 15, verticalAlign: "-2px", marginRight: 6, stroke: "currentColor", fill: "none", strokeWidth: 1.8 }} />Photo</button>
            <button className="sample" style={mode === "type" ? { background: "var(--color-surface)", color: "var(--color-ink)" } : null} onClick={() => setMode("type")}><Icon name="type" style={{ width: 15, height: 15, verticalAlign: "-2px", marginRight: 6, stroke: "currentColor", fill: "none", strokeWidth: 1.8 }} />Describe</button>
          </div>

          <div className="cap-actions">
            {mode === "photo" && (
              <button className="btn btn-ghost" onClick={() => fileRef.current?.click()}>
                <Icon name="plus" className="ar" /> {preview ? "Change photo" : "Add photo"}
              </button>
            )}
            <button className="btn btn-primary" disabled={busy || !canAnalyze} onClick={run}>
              {busy ? <><Icon name="loader" className="ar spin" /> Analyzing</> : <><Icon name="sparkle" className="ar" /> Analyze</>}
            </button>
          </div>
          <div className="muted" style={{ marginTop: 16, fontSize: "var(--text-sm)", lineHeight: "var(--leading-snug)" }}>
            Trigger assessments are informational and may be wrong. Log every day — the “nothing happened” data matters too.
          </div>
        </>
      )}

      {result && (
        <div className="cap-result">
          {preview && <img src={preview} alt="" style={{ width: "100%", borderRadius: "var(--radius-xl)", maxHeight: 220, objectFit: "cover", marginTop: 20 }} />}
          <div className="cap-rhead">
            <div className="t">{result.label}</div>
            {result.note && <div className="s">{result.note}</div>}
          </div>

          <div className="rlab">Triggers detected</div>
          {(result.triggers || []).length === 0 ? (
            <div className="food-clean" style={{ padding: "12px 0 0" }}><Icon name="check" /> No obvious dietary triggers</div>
          ) : (
            result.triggers.map((t, i) => (
              <div className="rtrig" key={i}>
                <span className={`dot ${t.level}`} />
                <div style={{ flex: 1 }}>
                  <div className="rt-top">
                    <span className="rt-nm">{t.name}</span>
                    <span className={`rt-lv ink-${t.level}`}>{t.level}</span>
                  </div>
                  <div className="rt-rs">{t.reason}</div>
                </div>
              </div>
            ))
          )}

          <button className="btn btn-primary btn-block" onClick={save}>
            <Icon name="check" className="ar" /> Save to today
          </button>
          <button className="btn btn-ghost btn-block" style={{ marginTop: 10 }} onClick={() => setResult(null)}>
            Redo
          </button>
        </div>
      )}
    </div>
  );
}

/* ---------- bottom nav + speed dial ---------- */
function BottomNav({ tab, setTab, addOpen, onToggleAdd, onPick }) {
  const FAN = [
    { k: "food", label: "Food", icon: "camera" },
    { k: "migraine", label: "Migraine", icon: "activity" },
    { k: "symptom", label: "Symptom", icon: "eye" },
    { k: "factors", label: "Daily factors", icon: "moon" },
  ];
  return (
    <>
      {addOpen && <div className="fan-scrim" onClick={onToggleAdd} />}
      {addOpen && (
        <div className="fan">
          {FAN.map((o, i) => (
            <button key={o.k} className="fanitem" style={{ animationDelay: `${(FAN.length - 1 - i) * 45}ms` }}
              onClick={() => onPick(o.k)}>
              <Icon name={o.icon} /> {o.label}
            </button>
          ))}
        </div>
      )}
      <div className="nav">
        <button className={`navbtn today ${tab === "today" ? "on" : ""}`} onClick={() => setTab("today")}>
          {new Date().getDate()}
        </button>
        <button className={`navbtn ${tab === "calendar" ? "on" : ""}`} onClick={() => setTab("calendar")}><Icon name="cal" /></button>
        <button className={`navadd ${addOpen ? "open" : ""}`} onClick={onToggleAdd}><Icon name="plus" /></button>
        <button className={`navbtn ${tab === "insights" ? "on" : ""}`} onClick={() => setTab("insights")}><Icon name="chart" /></button>
        <button className={`navbtn ${tab === "weather" ? "on" : ""}`} onClick={() => setTab("weather")}><Icon name="cloud" /></button>
      </div>
    </>
  );
}

Object.assign(window, {
  Sheet, Segmented, MigraineSheet, SymptomSheet, FactorsSheet, DayDetail, LogFoodCapture, BottomNav,
});
