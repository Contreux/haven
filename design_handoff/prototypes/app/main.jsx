/* ============================================================
   HAVEN — APP ROOT
   ============================================================ */
const { useState: uS, useEffect: uE, useCallback } = React;

function computeStreak(logs) {
  // consecutive days (ending today) with any entry
  let n = 0;
  const d = new Date();
  for (let i = 0; i < 60; i++) {
    const k = keyOf(d);
    const day = logs[k];
    const has = day && (day.foods?.length || day.factors || day.symptoms?.length || day.migraine?.had);
    if (has) n++; else if (i > 0) break; else if (!has) break;
    d.setDate(d.getDate() - 1);
  }
  return n;
}

function App() {
  const [theme, setTheme] = uS(() => localStorage.getItem("haven:theme") || "theme-dark");
  const [tab, setTab] = uS("today");
  const [logs, setLogs] = uS({});
  const [ready, setReady] = uS(false);
  const [weather] = uS(mockWeather());

  const [sheet, setSheet] = uS(null);      // "migraine" | "symptom" | "factors"
  const [capture, setCapture] = uS(false); // log-food overlay
  const [addOpen, setAddOpen] = uS(false);
  const [openDay, setOpenDay] = uS(null);

  const tk = todayKey();

  uE(() => {
    let l = loadLogs();
    if (!l) { l = seedData(); saveLogs(l); }
    setLogs(l); setReady(true);
  }, []);

  uE(() => { localStorage.setItem("haven:theme", theme); }, [theme]);

  const persist = useCallback((next) => { setLogs(next); saveLogs(next); }, []);

  const today = logs[tk];
  const streak = ready ? computeStreak(logs) : 0;

  /* ----- mutations ----- */
  const saveFood = (food) => {
    const day = logs[tk] || { foods: [], migraine: { had: false } };
    persist({ ...logs, [tk]: { ...day, foods: [...(day.foods || []), food] } });
    setCapture(false); setTab("today");
  };
  const deleteFood = (id) => {
    const day = logs[tk]; if (!day) return;
    persist({ ...logs, [tk]: { ...day, foods: (day.foods || []).filter((f) => f.id !== id) } });
  };
  const saveMig = (m) => { const day = logs[tk] || { foods: [] }; persist({ ...logs, [tk]: { ...day, migraine: m } }); setSheet(null); };
  const removeMig = () => { const day = logs[tk] || { foods: [] }; persist({ ...logs, [tk]: { ...day, migraine: { had: false } } }); setSheet(null); };
  const saveSym = (syms) => { const day = logs[tk] || { foods: [] }; persist({ ...logs, [tk]: { ...day, symptoms: syms } }); setSheet(null); };
  const saveFac = (f) => { const day = logs[tk] || { foods: [] }; persist({ ...logs, [tk]: { ...day, factors: f } }); setSheet(null); };

  /* ----- add speed-dial ----- */
  const pickAdd = (k) => {
    setAddOpen(false);
    if (k === "food") setCapture(true);
    else setSheet(k);
  };

  const resetData = () => { const l = seedData(); persist(l); setTab("today"); };

  return (
    <div className={`phone ${theme}`} id="phone">
      <div className="dyn" />
      <div className="screen">
        {!ready ? null : (
          <div className="screenwrap">
            <StatusBar />
            {tab === "today" && (
              <TodayScreen
                day={today} weather={weather} streak={streak}
                onWeather={() => setTab("weather")}
                onFactors={() => setSheet("factors")}
                onMigraine={() => setSheet("migraine")}
                onFood={() => setCapture(true)}
                onDeleteFood={deleteFood}
              />
            )}
            {tab === "calendar" && <CalendarScreen logs={logs} onOpenDay={(dk) => setOpenDay(dk)} />}
            {tab === "insights" && <InsightsScreen logs={logs} />}
            {tab === "weather" && <WeatherScreen weather={weather} />}

            <BottomNav
              tab={tab} setTab={(t) => { setTab(t); setAddOpen(false); }}
              addOpen={addOpen} onToggleAdd={() => setAddOpen((v) => !v)} onPick={pickAdd}
            />
          </div>
        )}

        {/* overlays */}
        {capture && <LogFoodCapture onClose={() => setCapture(false)} onSave={saveFood} />}
        {sheet === "migraine" && <MigraineSheet existing={today?.migraine} onClose={() => setSheet(null)} onSave={saveMig} onRemove={removeMig} />}
        {sheet === "symptom" && <SymptomSheet existing={today?.symptoms} onClose={() => setSheet(null)} onSave={saveSym} />}
        {sheet === "factors" && <FactorsSheet existing={today?.factors} onClose={() => setSheet(null)} onSave={saveFac} />}
        {openDay && <DayDetail dk={openDay} log={logs[openDay]} onClose={() => setOpenDay(null)} />}
      </div>

      {/* prototype chrome — portalled to body so it isn't scaled with the phone */}
      {ReactDOM.createPortal(
        <ProtoChrome theme={theme} setTheme={setTheme} resetData={resetData} />,
        document.body
      )}
    </div>
  );
}

function ProtoChrome({ theme, setTheme, resetData }) {
  return (
    <div className="proto-chrome">
      <button className="proto-btn" onClick={() => setTheme(theme === "theme-dark" ? "theme-light" : "theme-dark")}>
        <Icon name={theme === "theme-dark" ? "sun" : "moon"} />
        {theme === "theme-dark" ? "Light" : "Dark"}
      </button>
      <button className="proto-btn" onClick={resetData}>
        <Icon name="loader" /> Reset
      </button>
    </div>
  );
}

/* ---------- mount + responsive scale ---------- */
const root = ReactDOM.createRoot(document.getElementById("stage"));
root.render(<App />);

function fit() {
  const phone = document.getElementById("phone");
  if (!phone) return;
  const margin = 40;
  const sx = (window.innerWidth - margin) / 372;
  const sy = (window.innerHeight - margin) / 806;
  const s = Math.min(sx, sy, 1.3);
  phone.style.transform = `scale(${s})`;
}
window.addEventListener("resize", fit);
const fitObserver = new MutationObserver(fit);
fitObserver.observe(document.getElementById("stage"), { childList: true, subtree: true });
setTimeout(fit, 30);
setTimeout(fit, 200);
