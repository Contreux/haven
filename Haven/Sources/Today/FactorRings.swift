import SwiftUI
import HavenDesignSystem
import HavenCore

struct FactorRings: View {
    @Environment(\.theme) private var theme
    let factors: Factors?
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s4) {
            ring("Sleep", level: sleepLevel, value: sleepText)
            ring("Stress", level: factors?.stress ?? .mid, value: (factors?.stress ?? .mid).rawValue.capitalized)
            ring("Water", level: invert(factors?.hydration ?? .mid), value: (factors?.hydration ?? .mid).rawValue.capitalized)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    private var sleepLevel: Level {
        guard let h = factors?.sleepHours else { return .mid }
        return h >= 7.5 ? .low : (h >= 6 ? .mid : .high)   // less sleep → higher risk
    }
    private var sleepText: String {
        guard let h = factors?.sleepHours else { return "—" }
        return h.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0fh", h) : String(format: "%.1fh", h)
    }
    // Hydration: "low" water is high risk, so invert for the color scale.
    private func invert(_ l: Level) -> Level { l == .low ? .high : (l == .high ? .low : .mid) }

    private func ring(_ label: String, level: Level, value: String) -> some View {
        VStack(spacing: Spacing.s2) {
            ZStack {
                Circle().stroke(theme.track, lineWidth: Spacing.s2)
                Circle().trim(from: 0, to: fill(for: level))
                    .stroke(theme.factorColor(for: factorLevel(level)), style: StrokeStyle(lineWidth: Spacing.s2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value).havenText(.meta, color: theme.ink)
            }
            .frame(width: 64, height: 64)
            Text(label).havenText(.eyebrow, color: theme.inkFaint)
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }

    private func fill(for level: Level) -> CGFloat {
        switch level { case .low: 0.33; case .mid: 0.66; case .high: 1.0 }
    }
    // Map the risk Level onto the design system's FactorLevel.
    private func factorLevel(_ l: Level) -> FactorLevel {
        switch l { case .low: .low; case .mid: .medium; case .high: .high }
    }
}
