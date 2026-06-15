import SwiftUI
import HavenDesignSystem
import HavenCore

struct QuestionEditorSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let question: OnboardingQuestion
    @State var selection: [String]
    let onSave: ([String]) -> Void

    var body: some View {
        QuestionScreen(
            q: question, index: 0, total: 1,
            selected: $selection,
            onBack: { dismiss() },
            onNext: { onSave(selection); dismiss() }
        )
        .environment(\.theme, theme)
    }
}
