/* ============================================================
   HAVEN — ICONS  (stroke, currentColor, 24px viewBox)
   <Icon name="cal" /> — styled by parent via CSS (width/stroke).
   ============================================================ */
const PATHS = {
  search: '<circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/>',
  user: '<circle cx="12" cy="9" r="3.4"/><path d="M5.5 20c.6-3.5 3.3-5.2 6.5-5.2s5.9 1.7 6.5 5.2"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  home: '<path d="M4 11l8-7 8 7v8.5a1 1 0 0 1-1 1h-4.5V14h-5v6.5H5a1 1 0 0 1-1-1Z"/>',
  cal: '<rect x="4" y="5" width="16" height="16" rx="3"/><path d="M4 10h16M8 3v4M16 3v4"/>',
  chart: '<path d="M5 19V11M12 19V5M19 19v-5"/>',
  cloud: '<path d="M7 18a4 4 0 0 1-.5-7.97A5.5 5.5 0 0 1 17.5 11 3.5 3.5 0 0 1 17 18Z"/><path d="M9 21l-1 1M13 21l-1 1M17 21l-1 1"/>',
  cup: '<path d="M5 8h11v5a5 5 0 0 1-5 5H10a5 5 0 0 1-5-5V8Z"/><path d="M16 9h2.2a2.3 2.3 0 0 1 0 4.6H16"/><path d="M7 3v2M11 3v2"/>',
  plate: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3.4"/>',
  utensils: '<path d="M7 3v8a2 2 0 0 0 4 0V3M9 11v10M17 3c-1.5 0-2.5 2-2.5 5s1 4 2.5 4 2.5-1 2.5-4-1-5-2.5-5ZM17 16v5"/>',
  gauge: '<path d="M12 13l4-4M4.5 18a9 9 0 1 1 15 0"/><circle cx="12" cy="13" r="1.4" fill="currentColor" stroke="none"/>',
  wind: '<path d="M3 9h11a2.5 2.5 0 1 0-2.5-2.5M3 14h15a2.5 2.5 0 1 1-2.5 2.5M3 12h7"/>',
  droplet: '<path d="M12 3.5c3 3.6 5.5 6.2 5.5 9.5a5.5 5.5 0 0 1-11 0c0-3.3 2.5-5.9 5.5-9.5Z"/>',
  thermo: '<path d="M12 4a2 2 0 0 0-2 2v8.2a3.5 3.5 0 1 0 4 0V6a2 2 0 0 0-2-2Z"/><path d="M12 16.5a1.4 1.4 0 1 0 0 2.8 1.4 1.4 0 0 0 0-2.8Z" fill="currentColor" stroke="none"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4 12H2M22 12h-2M5 5l1.4 1.4M17.6 17.6 19 19M19 5l-1.4 1.4M6.4 17.6 5 19"/>',
  cloudcover: '<circle cx="9" cy="9" r="3.2"/><path d="M8 19h11a3 3 0 0 0 .3-6A4.5 4.5 0 0 0 11 11"/>',
  eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="2.6"/>',
  bone: '<path d="M7 17.5a2.3 2.3 0 1 1-2-2.3l8.2-8.2a2.3 2.3 0 1 1 3.6-1 2.3 2.3 0 1 1-1 3.6L7.6 17.8"/>',
  activity: '<path d="M3 12h4l2.5 7 5-14L17 12h4"/>',
  alert: '<path d="M12 4.5 21 19H3L12 4.5Z"/><path d="M12 10v4M12 16.5v.01"/>',
  sound: '<path d="M4 9v6h4l5 4V5L8 9H4Z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>',
  moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4 7 7 0 1 0 20 14.5Z"/>',
  zap: '<path d="M13 2 4 14h6l-1 8 9-12h-6l1-8Z"/>',
  camera: '<path d="M3 8.5A1.5 1.5 0 0 1 4.5 7h2L8 5h8l1.5 2h2A1.5 1.5 0 0 1 21 8.5v9A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5Z"/><circle cx="12" cy="13" r="3.4"/>',
  type: '<path d="M4 7V5h16v2M9 19h6M12 5v14"/>',
  check: '<path d="M5 12.5 10 17l9-10"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  chevL: '<path d="M15 5l-7 7 7 7"/>',
  chevR: '<path d="M9 5l7 7-7 7"/>',
  trash: '<path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13"/>',
  loader: '<path d="M12 3v4M12 17v4M5 12H3M21 12h-2M6 6l1.5 1.5M16.5 16.5 18 18M18 6l-1.5 1.5M7.5 16.5 6 18"/>',
  sparkle: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8L12 3Z"/>',
  pin: '<path d="M12 21s6-5.3 6-10a6 6 0 1 0-12 0c0 4.7 6 10 6 10Z"/><circle cx="12" cy="11" r="2.2"/>',
  flame: '<path d="M12 3c2.8 3.2 4.7 5.1 4.7 8.7A4.7 4.7 0 0 1 12 16.4c-1.1 0-2-.7-2-1.9 0-1.4 1.3-2 1.3-3.8 0 0-2.6 1.3-2.6 4.6 0 1.2.4 2.1.4 2.1A6.4 6.4 0 0 1 7 11.6C7 7.3 9.6 5.7 12 3Z"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16v4Z"/><path d="M14 6l4 4"/>',
  book: '<path d="M12 6c-1.6-1.2-3.6-1.8-6-1.8V17c2.4 0 4.4.6 6 1.8 1.6-1.2 3.6-1.8 6-1.8V4.2c-2.4 0-4.4.6-6 1.8Z"/><path d="M12 6v12.8"/>',
  trend: '<path d="M3 16l5-5 3 3 7-7M15 7h4v4"/>',
  scale: '<path d="M12 4v16M6 8h12M8 8l-3 6a3 3 0 0 0 6 0L8 8ZM16 8l-3 6a3 3 0 0 0 6 0l-3-6Z"/>',
};

function Icon({ name, className, style }) {
  const inner = PATHS[name] || "";
  return React.createElement("svg", {
    viewBox: "0 0 24 24", className, style,
    dangerouslySetInnerHTML: { __html: inner },
  });
}
window.Icon = Icon;
