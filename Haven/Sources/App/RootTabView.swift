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
        .sheet(item: $activeSheet) { kind in sheet(for: kind).environment(\.theme, theme) }
        .fullScreenCover(isPresented: $showProfile) {
            if let service = store.source as? ConvexService {
                ProfileScreen(source: service, onDataDeleted: { showProfile = false; onDataDeleted() })
                    .environment(\.theme, theme)
                    .environment(themeController)
            }
        }
        .overlay(alignment: .bottom) { if dialOpen { fanOverlay } }
    }

    private var bottomNav: some View {
        HStack(spacing: 0) {
            navButton(.today, system: "house")
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

    // Orange rounded-square FAB (per the design's navadd), raised above the bar.
    private var plusButton: some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { dialOpen.toggle() } } label: {
            Image(systemName: "plus").rotationEffect(.degrees(dialOpen ? 45 : 0))
                .foregroundStyle(theme.ctaInk).imageScale(.large)
                .frame(width: 54, height: 54)
                .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.lg))
                .shadow(color: theme.ctaShadow.swiftUIColor, radius: 14, x: 0, y: 8)
        }
        .frame(width: 60)
        .offset(y: -Spacing.s5)
        .accessibilityIdentifier("speed-dial")
    }

    private let loggerItems: [(LoggerKind, String, String)] = [
        (.food, "Food", "camera"), (.migraine, "Migraine", "bolt.heart"),
        (.symptom, "Symptom", "eye"), (.factors, "Daily factors", "moon"),
    ]

    // Dimmed/blurred backdrop + centered dark pills with cream labels + orange icons, per the design.
    private var fanOverlay: some View {
        ZStack(alignment: .bottom) {
            theme.bg.opacity(0.6).ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture { withAnimation { dialOpen = false } }
            VStack(spacing: Spacing.s3) {
                ForEach(loggerItems, id: \.0.id) { kind, label, icon in
                    Button { dialOpen = false; activeSheet = kind } label: {
                        HStack(spacing: Spacing.s3) {
                            Image(systemName: icon).foregroundStyle(theme.accent)
                            Text(label).havenText(.sectionHead, color: theme.tabActiveInk)
                        }
                        .padding(.leading, Spacing.s5).padding(.trailing, Spacing.s6).padding(.vertical, Spacing.s4)
                        .background(theme.tabActiveBg, in: Capsule())
                        .shadow(color: theme.ctaShadow.swiftUIColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .accessibilityIdentifier("dial-\(kind.rawValue)")
                }
            }
            .padding(.bottom, 104)
        }
    }

    private func navButton(_ t: Tab, system: String) -> some View {
        let on = tab == t
        return Button { tab = t } label: {
            Image(systemName: system).imageScale(.large)
                .foregroundStyle(on ? theme.tabActiveInk : theme.inkFaint)   // cream on the pill / faint when inactive
                .frame(width: 52, height: 34)
                .background(on ? theme.tabActiveBg : Color.clear, in: Capsule())   // active pill makes the selected tab legible
                .frame(maxWidth: .infinity, minHeight: 40)
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
