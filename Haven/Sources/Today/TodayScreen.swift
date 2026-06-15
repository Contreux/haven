import SwiftUI
import HavenDesignSystem
import HavenCore

struct TodayScreen: View {
    @Environment(\.theme) private var theme
    @State private var store: TodayStore
    @State private var activeSheet: LoggerKind?
    @State private var dialOpen = false

    init(store: TodayStore) { _store = State(initialValue: store) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    TopBar(dateText: prettyDate(store.today), streak: 1)
                    RiskHero(weather: store.weather)
                    HStack {
                        Text("Today's factors").havenText(.sectionHead, color: theme.ink)
                        Spacer()
                        Button { activeSheet = .factors } label: {
                            Text("Edit").havenText(.meta, color: theme.accent)
                        }
                    }
                    FactorRings(factors: store.day?.factors) { activeSheet = .factors }
                    ActionButtons(onLogMigraine: { activeSheet = .migraine }, onSnapMeal: { activeSheet = .food })
                    if let m = store.day?.migraine, m.had {
                        MigraineAlertCard(migraine: m)
                    }
                    if store.day?.factors != nil || !(store.day?.symptoms.isEmpty ?? true) {
                        SummaryCard(symptoms: store.day?.symptoms ?? [], factors: store.day?.factors)
                    }
                    LedgerView(entries: store.ledger)
                }
                .padding(Spacing.s6)
            }
            .overlay(alignment: .bottomTrailing) {
                SpeedDial(isOpen: $dialOpen) { kind in activeSheet = kind }
                    .padding(Spacing.s6)
            }
        }
        .task { store.start() }
        .sheet(item: $activeSheet) { kind in
            sheet(for: kind).environment(\.theme, theme)
        }
    }

    @ViewBuilder private func sheet(for kind: LoggerKind) -> some View {
        switch kind {
        case .migraine:
            MigraineSheet(existing: store.day?.migraine,
                          onSave: { try? await store.saveMigraine($0) },
                          onRemove: { try? await store.removeMigraine() })
        case .symptom:
            SymptomSheet(existing: store.day?.symptoms ?? []) { try? await store.saveSymptoms($0) }
        case .factors:
            FactorsSheet(initial: store.day?.factors) { try? await store.saveFactors($0) }
        case .food:
            FoodCaptureSheet(analyze: { await store.analyze($0) }) { food, imageData in
                await saveFood(food, imageData)
            }
        }
    }

    private func saveFood(_ food: FoodEntry, _ imageData: Data?) async {
        var entry = food
        if let imageData, let service = store.source as? ConvexService,
           let id = try? await service.uploadImage(imageData) {
            entry = FoodEntry(name: food.name, time: food.time, triggers: food.triggers, note: food.note, imageId: id)
        }
        try? await store.saveFood(entry)
    }

    private func prettyDate(_ ymd: String) -> String {
        let inF = DateFormatter()
        inF.locale = Locale(identifier: "en_US_POSIX")
        inF.calendar = Calendar(identifier: .gregorian)
        inF.dateFormat = "yyyy-MM-dd"
        let outF = DateFormatter(); outF.dateFormat = "EEEE, MMM d"   // display: locale-aware on purpose
        return inF.date(from: ymd).map(outF.string) ?? ymd
    }
}
