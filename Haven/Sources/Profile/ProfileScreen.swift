import SwiftUI
import HavenDesignSystem
import HavenCore

struct ProfileScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store: ProfileStore
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
                }
                .padding(Spacing.s7)
            }
        }
        .task { await store.load() }
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
