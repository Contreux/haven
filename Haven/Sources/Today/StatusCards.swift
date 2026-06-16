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
        // Design: two labeled sections — Symptoms (friendly-label chips) then Daily factors.
        VStack(alignment: .leading, spacing: Spacing.s5) {
            if !symptoms.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("Symptoms").havenText(.eyebrow, color: theme.inkSoft)
                    FlowChips(items: symptoms.map(SymptomCatalog.label(for:)))
                }
            }
            if let f = factors {
                let ws = f.weatherSensitive ? "  ·  Felt weather-sensitive" : ""
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("Daily factors").havenText(.eyebrow, color: theme.inkSoft)
                    Text("Sleep \(String(format: "%.1f", f.sleepHours))h  ·  Stress \(f.stress.rawValue)  ·  Water \(f.hydration.rawValue)\(ws)")
                        .havenText(.body, color: theme.inkSoft)
                }
            }
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }
}

/// Wrapping chip row (.chip-s): base-size semibold ink on a chip-fill pill.
struct FlowChips: View {
    @Environment(\.theme) private var theme
    let items: [String]
    var body: some View {
        FlowLayout(spacing: Spacing.s2) {
            ForEach(items, id: \.self) { item in
                Text(item).havenText(.chipName, color: theme.ink)
                    .fixedSize()
                    .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s2)
                    // chip == surface in the dark theme; recess with the page bg so it reads on the card.
                    .background(theme.bg, in: Capsule())
            }
        }
    }
}
