import SwiftUI
import HavenDesignSystem
import HavenCore

struct DayDetail: View {
    @Environment(\.theme) private var theme
    let day: DayLog?
    let date: String

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    SheetHeader(title: prettyDate(date), subtitle: "Logged that day")
                    if let day {
                        if let m = day.migraine, m.had { MigraineAlertCard(migraine: m) }
                        let entries = buildLedger(from: day)
                        if entries.isEmpty {
                            Text("Nothing logged.").havenText(.body, color: theme.inkFaint)
                        } else {
                            LedgerView(entries: entries)
                        }
                    } else {
                        Text("Nothing logged.").havenText(.body, color: theme.inkFaint)
                    }
                    Spacer()
                }
                .padding(Spacing.s6)
            }
        }
    }

    private func prettyDate(_ ymd: String) -> String {
        let inF = DateFormatter(); inF.locale = Locale(identifier: "en_US_POSIX")
        inF.calendar = Calendar(identifier: .gregorian); inF.dateFormat = "yyyy-MM-dd"
        let outF = DateFormatter(); outF.dateFormat = "EEEE, MMM d"
        return inF.date(from: ymd).map(outF.string) ?? ymd
    }
}
