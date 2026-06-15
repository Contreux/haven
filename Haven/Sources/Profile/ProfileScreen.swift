import SwiftUI
import StoreKit
import HavenDesignSystem
import HavenCore

struct ProfileScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeController.self) private var themeController
    @State private var store: ProfileStore
    @State private var editing: OnboardingQuestion?
    @State private var reminder = "evening"
    @State private var confirmingDelete = false
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
                    subscriptionSection
                    remindersSection
                    weatherSection
                    aboutSection
                    dataSection
                }
                .padding(Spacing.s7)
            }
        }
        .task {
            await store.load()
            reminder = store.settings.reminderTime.isEmpty ? "evening" : store.settings.reminderTime
        }
        .sheet(item: $editing) { q in
            QuestionEditorSheet(question: q, selection: store.answers[q.id] ?? []) { values in
                Task { await store.saveAnswer(questionId: q.id, values: values) }
            }
            .environment(\.theme, theme)
        }
        .confirmationDialog("Delete all your data?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                Task { await store.deleteData(); onDataDeleted() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your logs and profile, and returns you to setup.")
        }
    }

    private var dataSection: some View {
        sectionCard("DATA & PRIVACY") {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                ShareLink(item: DoctorReport.text(days: store.days, klass: store.profile.klass)) {
                    HStack { Text("Export report").havenText(.body, color: theme.ink); Spacer()
                        Image(systemName: "square.and.arrow.up").foregroundStyle(theme.inkFaint) }
                }
                .accessibilityIdentifier("profile-export")
                Button { confirmingDelete = true } label: {
                    HStack { Text("Delete my data").havenText(.body, color: theme.accent); Spacer()
                        Image(systemName: "trash").foregroundStyle(theme.accent) }
                }
                .accessibilityIdentifier("profile-delete")
            }
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

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(title).havenText(.eyebrow, color: theme.inkFaint)
            content()
                .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    private var subscriptionSection: some View {
        sectionCard("SUBSCRIPTION") {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text(store.settings.subscribed ? "Haven Premium — active" : "Free plan")
                    .havenText(.body, color: theme.ink)
                HStack(spacing: Spacing.s5) {
                    Button("Manage") { Task { try? await AppStore.showManageSubscriptions(in: scene) } }
                        .havenText(.meta, color: theme.accent)
                    Button("Restore") { }
                        .havenText(.meta, color: theme.accent)
                        .accessibilityIdentifier("profile-restore")
                }
            }
        }
    }

    private var remindersSection: some View {
        sectionCard("REMINDERS") {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Daily reminder").havenText(.body, color: theme.ink)
                Picker("", selection: $reminder) {
                    Text("Morning").tag("morning"); Text("Afternoon").tag("afternoon"); Text("Evening").tag("evening")
                }
                .pickerStyle(.segmented)
                .onChange(of: reminder) { _, t in Task { await store.setReminderTime(t) } }
            }
        }
    }

    private var weatherSection: some View {
        sectionCard("WEATHER & LOCATION") {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text(store.settings.lat == nil ? "Barometric risk off" : "Barometric risk on")
                    .havenText(.body, color: theme.ink)
                if let lat = store.settings.lat, let lon = store.settings.lon {
                    Text(String(format: "%.2f, %.2f", lat, lon)).havenText(.meta, color: theme.inkSoft)
                } else {
                    Text("Location not set").havenText(.meta, color: theme.inkSoft)
                }
            }
        }
    }

    private var aboutSection: some View {
        sectionCard("ABOUT") {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HStack {
                    Text("Dark theme").havenText(.body, color: theme.ink)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { themeController.mode == .dark },
                        set: { _ in themeController.toggle() })).labelsHidden()
                }
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .havenText(.meta, color: theme.inkFaint)
            }
        }
    }

    private var scene: UIWindowScene {
        UIApplication.shared.connectedScenes.first as! UIWindowScene
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
