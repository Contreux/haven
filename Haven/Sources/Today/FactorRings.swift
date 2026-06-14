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

struct FactorEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let initial: Factors?
    let onSave: (Factors) async -> Void

    @State private var sleep: Double
    @State private var stress: Level
    @State private var hydration: Level
    @State private var weatherSensitive: Bool

    init(initial: Factors?, onSave: @escaping (Factors) async -> Void) {
        self.initial = initial
        self.onSave = onSave
        _sleep = State(initialValue: initial?.sleepHours ?? 7)
        _stress = State(initialValue: initial?.stress ?? .mid)
        _hydration = State(initialValue: initial?.hydration ?? .mid)
        _weatherSensitive = State(initialValue: initial?.weatherSensitive ?? true)
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s6) {
                Text("Daily factors").havenText(.sectionHead, color: theme.ink)

                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Sleep: \(String(format: "%.1f", sleep))h").havenText(.body, color: theme.inkSoft)
                    Stepper("", value: $sleep, in: 0...12, step: 0.5).labelsHidden().tint(theme.accent)
                }
                picker("Stress", selection: $stress)
                picker("Hydration", selection: $hydration)
                Toggle(isOn: $weatherSensitive) {
                    Text("Weather sensitive").havenText(.body, color: theme.inkSoft)
                }.tint(theme.accent)

                Button {
                    Task {
                        await onSave(Factors(sleepHours: sleep, stress: stress,
                                             hydration: hydration, weatherSensitive: weatherSensitive))
                        dismiss()
                    }
                } label: {
                    Text("Save").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                Spacer()
            }
            .padding(Spacing.s6)
        }
    }

    private func picker(_ label: String, selection: Binding<Level>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(label).havenText(.eyebrow, color: theme.inkFaint)
            Picker(label, selection: selection) {
                Text("Low").tag(Level.low); Text("Mid").tag(Level.mid); Text("High").tag(Level.high)
            }.pickerStyle(.segmented)
        }
    }
}
