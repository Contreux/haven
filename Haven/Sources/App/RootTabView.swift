import SwiftUI
import HavenDesignSystem
import HavenCore

struct RootTabView: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeController.self) private var themeController
    @State private var store: TodayStore
    @State private var tab: Tab = .today
    @State private var activeSheet: LoggerKind?
    @State private var dialOpen = false
    @State private var showProfile = false
    var onDataDeleted: () -> Void = {}

    enum Tab { case today, calendar, insights, weather }

    init(store: TodayStore, onDataDeleted: @escaping () -> Void = {}) {
        _store = State(initialValue: store)
        self.onDataDeleted = onDataDeleted
    }

    var body: some View {
        Group {
            switch tab {
            case .today: TodayScreen(store: store, onLogger: { activeSheet = $0 }, onProfile: { showProfile = true })
            case .calendar: CalendarScreen(store: store)
            case .insights: InsightsScreen(store: store)
            case .weather: WeatherScreen(weather: store.weather)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomNav }   // insets content so nothing hides behind the bar
        .task { store.start() }
        .sheet(item: $activeSheet) { kind in
            Group {
                // The menu scanner is scrollable/dynamic, so it uses a resizable bottom sheet;
                // the other loggers size to their content.
                if kind == .menu { sheet(for: kind).bottomSheetChrome() }
                else { sheet(for: kind).contentSizedSheet() }
            }
            .environment(\.theme, theme)
        }
        .fullScreenCover(isPresented: $showProfile) {
            if let service = store.source as? ConvexService {
                ProfileScreen(source: service, onDataDeleted: { showProfile = false; onDataDeleted() })
                    .environment(\.theme, theme)
                    .environment(themeController)
            }
        }
        .overlay(alignment: .bottom) {
            if dialOpen {
                FanOverlay(items: loggerItems, onPick: { activeSheet = $0 }, onClose: { dialOpen = false })
            }
        }
    }

    private var bottomNav: some View {
        HStack(spacing: 0) {
            todayButton   // the today tab shows the date number, per the design
            navButton(.calendar, system: "calendar")
            plusButton   // center FAB, per the design
            navButton(.insights, system: "chart.bar")
            navButton(.weather, system: "cloud")
        }
        .padding(.horizontal, Spacing.s6)
        .padding(.top, Spacing.s4)
        .background(theme.tabbarBg.ignoresSafeArea(edges: .bottom))
        .accessibilityIdentifier("bottom-nav")
    }

    // Orange FAB (the design's navadd): a rounded square that rotates 45° to a diamond
    // (and turns the + into an ×) when the fan is open.
    private var plusButton: some View {
        Button { withAnimation(.easeOut(duration: 0.25)) { dialOpen.toggle() } } label: {
            RoundedRectangle(cornerRadius: Radius.lg).fill(theme.accent)
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundStyle(theme.ctaInk))
                .rotationEffect(.degrees(dialOpen ? 45 : 0))
                .shadow(color: theme.ctaShadow.swiftUIColor, radius: 14, x: 0, y: 8)
        }
        .frame(width: 60)
        .offset(y: -Spacing.s1)
        .accessibilityIdentifier("speed-dial")
    }

    // Order matches the design: Scan a menu (top) → Food → Migraine → Symptom → Daily factors (bottom).
    private let loggerItems: [(LoggerKind, String, String)] = [
        (.menu, "Scan a menu", "book"),
        (.food, "Food", "camera"),
        (.migraine, "Migraine", "waveform.path.ecg"),
        (.symptom, "Symptom", "eye"),
        (.factors, "Daily factors", "moon"),
    ]

    private var todayButton: some View {
        let on = tab == .today
        let day = Calendar.current.component(.day, from: Date())
        return Button { tab = .today } label: {
            Text("\(day)").havenText(.sectionHead, color: on ? theme.tabActiveInk : theme.inkFaint)
                .frame(width: 44, height: 44)
                .background(on ? theme.tabActiveBg : Color.clear, in: RoundedRectangle(cornerRadius: Radius.md))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("tab-today")
    }

    private func navButton(_ t: Tab, system: String) -> some View {
        let on = tab == t
        // Per the design only the today tab gets a background; the others just change color.
        return Button { tab = t } label: {
            Image(systemName: system).imageScale(.large)
                .foregroundStyle(on ? theme.tabActiveInk : theme.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("tab-\(label(t))")
    }
    private func label(_ t: Tab) -> String { switch t { case .today: "today"; case .calendar: "calendar"; case .insights: "insights"; case .weather: "weather" } }

    @ViewBuilder private func sheet(for kind: LoggerKind) -> some View {
        switch kind {
        case .migraine: MigraineSheet(existing: store.day?.migraine, onSave: { try? await store.saveMigraine($0) }, onRemove: { try? await store.removeMigraine() })
        case .symptom: SymptomSheet(existing: store.day?.symptoms ?? []) { try? await store.saveSymptoms($0) }
        case .factors: FactorsSheet(initial: store.day?.factors) { try? await store.saveFactors($0) }
        case .food: FoodCaptureSheet(
            analyze: { await store.analyze($0) },
            analyzeImage: { data, hint in await store.analyzeImage(imageBase64: data.base64EncodedString(), hint: hint) },
            onSave: { food, imageData in await saveFood(food, imageData) })
        case .menu: MenuScanSheet(
            scanMenu: { data in await store.scanMenu(imageBase64: data.base64EncodedString()) },
            onLog: { food in try? await store.saveFood(food) })
        }
    }
    private func saveFood(_ food: FoodEntry, _ imageData: Data?) async {
        var entry = food
        if let imageData, let service = store.source as? ConvexService, let id = try? await service.uploadImage(imageData) {
            entry = FoodEntry(name: food.name, time: food.time, triggers: food.triggers, note: food.note, imageId: id)
        }
        try? await store.saveFood(entry)
    }
}

/// The speed-dial fan: a dimmed backdrop and centered dark pills that stagger in (bottom-first),
/// matching the design's `.fan-scrim` / `.fanitem`.
private struct FanOverlay: View {
    @Environment(\.theme) private var theme
    let items: [(LoggerKind, String, String)]
    let onPick: (LoggerKind) -> Void
    let onClose: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.bg.opacity(shown ? 0.55 : 0).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .animation(.easeOut(duration: 0.2), value: shown)
            VStack(spacing: Spacing.s3) {
                ForEach(Array(items.enumerated()), id: \.element.0.id) { i, item in
                    let (kind, label, icon) = item
                    Button { onClose(); onPick(kind) } label: {
                        HStack(spacing: Spacing.s4) {
                            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(theme.accent)
                            Text(label).havenText(.sectionHead, color: theme.tabActiveInk)
                        }
                        .padding(.vertical, 12).padding(.leading, Spacing.s6).padding(.trailing, Spacing.s8)
                        .background(theme.tabActiveBg, in: Capsule())
                        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 10)
                    }
                    .accessibilityIdentifier("dial-\(kind.rawValue)")
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 10)
                    .scaleEffect(shown ? 1 : 0.98)
                    // Bottom item appears first (45ms stagger), per the design.
                    .animation(.spring(response: 0.34, dampingFraction: 0.82).delay(Double(items.count - 1 - i) * 0.045), value: shown)
                }
            }
            .padding(.bottom, 104)
        }
        .onAppear { shown = true }
    }
}
