import SwiftUI
import HavenDesignSystem
import HavenCore

struct LedgerView: View {
    @Environment(\.theme) private var theme
    let entries: [LedgerEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("Logged today").havenText(.sectionHead, color: theme.ink)
            if entries.isEmpty {
                Text("Nothing logged yet today.").havenText(.body, color: theme.inkFaint)
                    .padding(.vertical, Spacing.s5)
            } else {
                VStack(spacing: Spacing.s3) {
                    ForEach(entries) { LedgerRow(entry: $0) }
                }
            }
        }
    }
}

struct LedgerRow: View {
    @Environment(\.theme) private var theme
    let entry: LedgerEntry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            Image(systemName: icon).foregroundStyle(accent).frame(width: Spacing.s7)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text(entry.title).havenText(.body, color: theme.ink)
                Text(entry.subtitle).havenText(.meta, color: theme.inkSoft)
                if !entry.triggers.isEmpty {
                    HStack(spacing: Spacing.s2) {
                        ForEach(entry.triggers) { t in
                            Text(t.label).havenText(.eyebrow, color: theme.ink)
                                .padding(.horizontal, Spacing.s3).padding(.vertical, Spacing.s1)
                                .background(theme.factorColor(for: factorLevel(t.level)).opacity(0.2), in: Capsule())
                        }
                    }
                }
            }
            Spacer()
            Text(entry.time).havenText(.meta, color: theme.inkFaint)
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var icon: String {
        switch entry.kind {
        case .factors: "circle.grid.2x2"
        case .food: "fork.knife"
        case .symptoms: "waveform.path.ecg"
        case .migraine: "bolt.heart"
        }
    }
    private var accent: Color {
        switch entry.kind {
        case .migraine: theme.factorHigh
        case .factors: theme.accent
        default: theme.inkSoft
        }
    }
    private func factorLevel(_ l: Level) -> FactorLevel {
        switch l { case .low: .low; case .mid: .medium; case .high: .high }
    }
}
