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
                    FlowLayout(spacing: Spacing.s2) {
                        ForEach(entry.triggers) { TriggerPill(trigger: $0) }
                    }
                    .padding(.top, Spacing.s1)
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
}

/// A single trigger pill on a logged entry: colored dot + name + level, matching the design's `.trig`.
/// The name stays on one line (no internal wrapping); chips wrap as a group via `FlowLayout`.
struct TriggerPill: View {
    @Environment(\.theme) private var theme
    let trigger: TriggerChip

    var body: some View {
        HStack(spacing: Spacing.s2) {
            Circle().fill(theme.factorColor(for: factorLevel(trigger.level)))
                .frame(width: 7, height: 7)
            Text(trigger.label).havenText(.chipName, color: theme.ink).lineLimit(1)
            Text(trigger.level.rawValue).havenText(.eyebrow, color: theme.inkSoft)
        }
        .fixedSize()
        .padding(.horizontal, Spacing.s3).padding(.vertical, Spacing.s2)
        // chip == surface in the dark theme, so a flush pill is invisible on the card;
        // recess it with the darker page background so it reads as a discrete badge.
        .background(theme.bg, in: Capsule())
    }
    private func factorLevel(_ l: Level) -> FactorLevel {
        switch l { case .low: .low; case .mid: .medium; case .high: .high }
    }
}
