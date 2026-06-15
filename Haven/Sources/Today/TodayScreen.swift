import SwiftUI
import HavenDesignSystem
import HavenCore

struct TodayScreen: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeController.self) private var controller
    @State private var store: TodayStore
    @State private var editingFactors = false

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
                        Button { editingFactors = true } label: {
                            Text("Edit").havenText(.meta, color: theme.accent)
                        }
                    }
                    FactorRings(factors: store.day?.factors) { editingFactors = true }
                    ActionButtons()
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
                Button { controller.toggle() } label: {
                    Image(systemName: controller.mode == .dark ? "sun.max.fill" : "moon.fill")
                        .foregroundStyle(theme.ctaInk).padding(Spacing.s5)
                        .background(theme.ctaBg, in: Circle())
                }
                .padding(Spacing.s6)
                .accessibilityIdentifier("theme-toggle")
            }
        }
        .task { store.start() }
        .sheet(isPresented: $editingFactors) {
            FactorsSheet(initial: store.day?.factors) { factors in
                try? await store.saveFactors(factors)
            }
            .environment(\.theme, theme)
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
