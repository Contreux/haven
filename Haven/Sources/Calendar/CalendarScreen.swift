import SwiftUI
import HavenDesignSystem
import HavenCore

struct CalendarScreen: View {
    @Environment(\.theme) private var theme
    let store: TodayStore
    @State private var year: Int
    @State private var month: Int
    @State private var openDate: String?

    init(store: TodayStore) {
        self.store = store
        let parts = store.today.split(separator: "-")
        _year = State(initialValue: Int(parts[0]) ?? 2026)
        _month = State(initialValue: Int(parts[1]) ?? 1)
    }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 7)
    private let dow = ["S", "M", "T", "W", "T", "F", "S"]
    private let months = ["January","February","March","April","May","June","July","August","September","October","November","December"]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("Calendar").havenText(.screenTitle, color: theme.ink)
                    HStack {
                        Button { step(-1) } label: { Image(systemName: "chevron.left").foregroundStyle(theme.inkSoft) }
                        Spacer()
                        Text("\(months[month-1]) \(String(year))").havenText(.sectionHead, color: theme.ink)
                        Spacer()
                        Button { step(1) } label: { Image(systemName: "chevron.right").foregroundStyle(theme.inkSoft) }
                    }
                    HStack { ForEach(0..<7, id: \.self) { i in Text(dow[i]).havenText(.eyebrow, color: theme.inkFaint).frame(maxWidth: .infinity) } }
                    LazyVGrid(columns: cols, spacing: Spacing.s2) {
                        ForEach(store.calendar(year: year, month: month).cells) { cell in
                            cellView(cell)
                        }
                    }
                    legend
                }
                .padding(Spacing.s6)
            }
        }
        .sheet(item: Binding(get: { openDate.map { IdString($0) } }, set: { openDate = $0?.value })) { id in
            DayDetail(day: store.allDays.first { $0.date == id.value }, date: id.value)
                .environment(\.theme, theme)
        }
    }

    private func step(_ d: Int) {
        var m = month + d, y = year
        if m < 1 { m = 12; y -= 1 }; if m > 12 { m = 1; y += 1 }
        month = m; year = y
    }

    @ViewBuilder private func cellView(_ cell: CalendarCell) -> some View {
        if let day = cell.day {
            Button { openDate = cell.date } label: {
                VStack(spacing: Spacing.s1) {
                    Text("\(day)").havenText(.meta, color: cell.isToday ? theme.ctaInk : theme.ink)
                    mark(cell)
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(cell.isToday ? theme.ctaBg : Color.clear, in: RoundedRectangle(cornerRadius: Radius.sm))
            }
        } else {
            Color.clear.frame(height: 44)
        }
    }

    @ViewBuilder private func mark(_ cell: CalendarCell) -> some View {
        if let sev = cell.migraineSeverity {
            Circle().stroke(severityColor(sev), lineWidth: 2).frame(width: Spacing.s4, height: Spacing.s4)
        } else if cell.mark == .food {
            Circle().fill(theme.accent).frame(width: Spacing.s2, height: Spacing.s2)
        } else if cell.mark == .symptoms {
            Circle().fill(theme.inkSoft).frame(width: Spacing.s2, height: Spacing.s2)
        } else {
            Color.clear.frame(height: Spacing.s2)
        }
    }

    private func severityColor(_ sev: String) -> Color {
        switch sev.lowercased() {
        case "severe": theme.factorColor(for: .high)
        case "mild": theme.factorColor(for: .medium)
        default: theme.accent
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            legendRow(Circle().stroke(theme.accent, lineWidth: 2).frame(width: Spacing.s4, height: Spacing.s4), "Migraine (ring = severity)")
            legendRow(Circle().fill(theme.accent).frame(width: Spacing.s2, height: Spacing.s2), "Food logged")
            legendRow(Circle().fill(theme.inkSoft).frame(width: Spacing.s2, height: Spacing.s2), "Symptoms")
        }
    }
    private func legendRow<V: View>(_ glyph: V, _ label: String) -> some View {
        HStack(spacing: Spacing.s3) { glyph; Text(label).havenText(.meta, color: theme.inkSoft) }
    }
}

struct IdString: Identifiable { let value: String; init(_ v: String) { value = v }; var id: String { value } }
