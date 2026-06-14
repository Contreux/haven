import SwiftUI
import HavenDesignSystem
import HavenCore

struct MigraineAlertCard: View {
    @Environment(\.theme) private var theme
    let migraine: Migraine

    var body: some View {
        HStack(spacing: Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.factorHigh)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Migraine logged · \(migraine.time)").havenText(.sectionHead, color: theme.ink)
                Text("\(migraine.severity.capitalized)\(migraine.notes.isEmpty ? "" : " · \(migraine.notes)")")
                    .havenText(.meta, color: theme.inkSoft)
            }
            Spacer()
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).stroke(theme.factorHigh, lineWidth: 1))
    }
}

struct SummaryCard: View {
    @Environment(\.theme) private var theme
    let symptoms: [String]
    let factors: Factors?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Today's status").havenText(.eyebrow, color: theme.inkFaint)
            if !symptoms.isEmpty {
                FlowChips(items: symptoms)
            }
            if let f = factors {
                Text("Sleep \(String(format: "%.1f", f.sleepHours))h · Stress \(f.stress.rawValue) · Water \(f.hydration.rawValue)")
                    .havenText(.body, color: theme.inkSoft)
            }
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }
}

/// Simple wrapping chip row.
struct FlowChips: View {
    @Environment(\.theme) private var theme
    let items: [String]
    var body: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(items, id: \.self) { item in
                Text(item).havenText(.meta, color: theme.ink)
                    .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s2)
                    .background(theme.chip, in: Capsule())
            }
        }
    }
}
