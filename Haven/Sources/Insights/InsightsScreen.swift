import SwiftUI
import HavenDesignSystem
import HavenCore

struct InsightsScreen: View {
    @Environment(\.theme) private var theme
    let store: TodayStore

    var body: some View {
        let r = store.insights
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("Insights").havenText(.screenTitle, color: theme.ink)
                    HStack(spacing: Spacing.s3) {
                        stat("\(r.migraineDays)", "Migraine days", theme.factorHigh)
                        stat("\(r.trackedDays)", "Days tracked", theme.ink)
                        stat("\(r.triggersSeen)", "Triggers seen", theme.accent)
                    }
                    Text("Your triggers").havenText(.sectionHead, color: theme.ink)
                    Text("Ranked by how often they land on a migraine day.").havenText(.meta, color: theme.inkSoft)
                    if r.ranked.isEmpty {
                        Text("Log a few meals to start building your trigger ranking.")
                            .havenText(.body, color: theme.inkFaint).padding(.vertical, Spacing.s5)
                    } else {
                        ForEach(Array(r.ranked.enumerated()), id: \.element.id) { i, t in
                            triggerRow(rank: i + 1, stat: t, maxTotal: r.ranked.map(\.total).max() ?? 1)
                        }
                    }
                    noteCard
                }
                .padding(Spacing.s6)
            }
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Text(value).havenText(.riskWord, color: color)
            Text(label).havenText(.meta, color: theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s4).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private func triggerRow(rank: Int, stat t: TriggerStat, maxTotal: Int) -> some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            Text("\(rank)").havenText(.sectionHead, color: theme.inkFaint).frame(width: Spacing.s7)
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack {
                    Text(t.name).havenText(.body, color: theme.ink)
                    Spacer()
                    Text(t.onMigraine > 0 ? "\(t.onMigraine) migraine\(t.onMigraine == 1 ? "" : "s")" : "no overlap")
                        .havenText(.meta, color: t.onMigraine > 0 ? theme.factorHigh : theme.inkSoft)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.track)
                        Capsule().fill(theme.factorColor(for: factorLevel(t.level)))
                            .frame(width: geo.size.width * CGFloat(t.total) / CGFloat(max(1, maxTotal)))
                    }
                }.frame(height: Spacing.s2)
                Text("Eaten \(t.total) time\(t.total == 1 ? "" : "s")").havenText(.meta, color: theme.inkFaint)
            }
        }
        .padding(Spacing.s4).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: Spacing.s2) { Image(systemName: "sparkles").foregroundStyle(theme.accent); Text("A note on patterns").havenText(.sectionHead, color: theme.ink) }
            Text("This is a list of hypotheses to test, not conclusions. Triggers stack — a food often only sets things off alongside poor sleep, stress or dehydration. Look for patterns over weeks, not single days.")
                .havenText(.body, color: theme.inkSoft)
        }
        .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }

    private func factorLevel(_ l: Level) -> FactorLevel {
        switch l { case .low: .low; case .mid: .medium; case .high: .high }
    }
}
