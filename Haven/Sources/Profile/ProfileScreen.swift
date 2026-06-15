import SwiftUI
import HavenDesignSystem
import HavenCore

struct ProfileScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store: ProfileStore
    @State private var editing: OnboardingQuestion?
    let onDataDeleted: () -> Void

    init(source: DayDataSource, onDataDeleted: @escaping () -> Void) {
        _store = State(initialValue: ProfileStore(source: source))
        self.onDataDeleted = onDataDeleted
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    header
                    profileSection
                }
                .padding(Spacing.s7)
            }
        }
        .task { await store.load() }
        .sheet(item: $editing) { q in
            QuestionEditorSheet(question: q, selection: store.answers[q.id] ?? []) { values in
                Task { await store.saveAnswer(questionId: q.id, values: values) }
            }
            .environment(\.theme, theme)
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("YOUR MIGRAINE PROFILE").havenText(.eyebrow, color: theme.inkFaint)
            ForEach(store.rows) { row in
                Button { editing = OnboardingCatalog.questions.first { $0.id == row.questionId } } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text(row.title).havenText(.meta, color: theme.inkSoft)
                            Text(row.value).havenText(.body, color: theme.ink)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(theme.inkFaint)
                    }
                    .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .accessibilityIdentifier("profile-row-\(row.questionId)")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Your profile").havenText(.screenTitle, color: theme.ink)
                Text(store.profile.klass).havenText(.body, color: theme.inkSoft)
                Text("Sign in to sync (coming soon)").havenText(.meta, color: theme.inkFaint)
            }
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(theme.inkSoft) }
                .accessibilityIdentifier("profile-close")
        }
    }
}
