import SwiftUI
import HavenDesignSystem
import HavenCore

struct FactorsSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let initial: Factors?
    let onSave: (Factors) async -> Void

    @State private var sleep: Double
    @State private var stress: String
    @State private var hydration: String
    @State private var weatherSensitive: Bool

    init(initial: Factors?, onSave: @escaping (Factors) async -> Void) {
        self.initial = initial; self.onSave = onSave
        _sleep = State(initialValue: initial?.sleepHours ?? 7)
        _stress = State(initialValue: (initial?.stress ?? .mid).rawValue.capitalized)
        _hydration = State(initialValue: (initial?.hydration ?? .mid).rawValue.capitalized)
        _weatherSensitive = State(initialValue: initial?.weatherSensitive ?? false)
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                SheetHeader(title: "Daily factors", subtitle: "Often more predictive than food alone.")
                HStack {
                    Text("SLEEP").havenText(.eyebrow, color: theme.inkFaint)
                    Spacer()
                    Text(String(format: "%.1fh", sleep)).havenText(.meta, color: theme.ink)
                }
                Slider(value: $sleep, in: 0...12, step: 0.5).tint(theme.accent)
                Text("STRESS").havenText(.eyebrow, color: theme.inkFaint)
                Segmented(options: ["Low", "Mid", "High"], selection: $stress)
                Text("HYDRATION").havenText(.eyebrow, color: theme.inkFaint)
                Segmented(options: ["Low", "Mid", "High"], selection: $hydration)
                Toggle(isOn: $weatherSensitive) {
                    Text("I felt weather-sensitive today").havenText(.body, color: theme.inkSoft)
                }.tint(theme.accent)
                Button {
                    Task {
                        await onSave(Factors(sleepHours: sleep, stress: level(stress),
                                             hydration: level(hydration), weatherSensitive: weatherSensitive))
                        dismiss()
                    }
                } label: {
                    Text("Save").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                .accessibilityIdentifier("factors-save")
                Spacer()
            }
            .padding(Spacing.s6)
        }
    }

    private func level(_ s: String) -> Level {
        switch s.lowercased() { case "low": .low; case "high": .high; default: .mid }
    }
}
