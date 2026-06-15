import SwiftUI
import HavenDesignSystem
import HavenCore

struct RootTabView: View {
    @Environment(\.theme) private var theme
    @State private var store: TodayStore
    @State private var tab: Tab = .today
    @State private var activeSheet: LoggerKind?
    @State private var dialOpen = false

    enum Tab { case today, calendar, insights, weather }

    init(store: TodayStore) { _store = State(initialValue: store) }

    var body: some View {
        Group {
            switch tab {
            case .today: TodayScreen(store: store, onLogger: { activeSheet = $0 })
            case .calendar: CalendarScreen(store: store)
            case .insights: InsightsScreen(store: store)
            case .weather: WeatherScreen(weather: store.weather)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomNav }   // insets content so nothing hides behind the bar
        .task { store.start() }
        .sheet(item: $activeSheet) { kind in sheet(for: kind).environment(\.theme, theme) }
        .overlay(alignment: .bottomTrailing) {
            SpeedDial(isOpen: $dialOpen) { kind in activeSheet = kind }
                .padding(.trailing, Spacing.s6).padding(.bottom, 96)
        }
    }

    private var bottomNav: some View {
        HStack(spacing: 0) {
            navButton(.today, system: "house")
            navButton(.calendar, system: "calendar")
            Spacer().frame(width: 56) // center speed-dial gap
            navButton(.insights, system: "chart.bar")
            navButton(.weather, system: "cloud")
        }
        .padding(.horizontal, Spacing.s6)
        .padding(.top, Spacing.s4)
        .background(theme.tabbarBg.ignoresSafeArea(edges: .bottom))
        .accessibilityIdentifier("bottom-nav")
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
        case .food: FoodCaptureSheet(analyze: { await store.analyze($0) }) { food, imageData in await saveFood(food, imageData) }
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
