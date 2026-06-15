import SwiftUI
import HavenDesignSystem
import HavenCore

struct TodayScreen: View {
    @Environment(\.theme) private var theme
    @State private var store: TodayStore
    private let onLogger: (LoggerKind) -> Void

    init(store: TodayStore, onLogger: @escaping (LoggerKind) -> Void) {
        _store = State(initialValue: store)
        self.onLogger = onLogger
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    TopBar(dateText: prettyDate(store.today), streak: store.streak)
                    RiskHero(weather: store.weather)
                    HStack {
                        Text("Today's factors").havenText(.sectionHead, color: theme.ink)
                        Spacer()
                        Button { onLogger(.factors) } label: {
                            Text("Edit").havenText(.meta, color: theme.accent)
                        }
                    }
                    FactorRings(factors: store.day?.factors) { onLogger(.factors) }
                    ActionButtons(onLogMigraine: { onLogger(.migraine) }, onSnapMeal: { onLogger(.food) })
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
        }
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
