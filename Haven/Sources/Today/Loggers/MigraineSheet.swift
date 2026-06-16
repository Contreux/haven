import SwiftUI
import HavenDesignSystem
import HavenCore

struct MigraineSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let existing: Migraine?
    let onSave: (Migraine) async -> Void
    let onRemove: () async -> Void

    @State private var severity: String
    @State private var notes: String

    init(existing: Migraine?, onSave: @escaping (Migraine) async -> Void, onRemove: @escaping () async -> Void) {
        self.existing = existing; self.onSave = onSave; self.onRemove = onRemove
        // Normalize to the segmented control's capitalized options (stored data may be lowercase).
        _severity = State(initialValue: existing?.severity.isEmpty == false ? existing!.severity.capitalized : "Moderate")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            SheetHeader(title: "Log a migraine", subtitle: "How is it right now?")
            Text("SEVERITY").havenText(.eyebrow, color: theme.inkFaint)
            Segmented(options: ["Mild", "Moderate", "Severe"], selection: $severity)
            Text("NOTES").havenText(.eyebrow, color: theme.inkFaint)
            TextEditor(text: $notes)
                .frame(height: 100).scrollContentBackground(.hidden)
                .padding(Spacing.s3).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .havenText(.body, color: theme.ink)
            Button {
                Task { await onSave(Migraine(had: true, severity: severity, time: TodayStore.nowHM(), notes: notes)); dismiss() }
            } label: {
                Text("Save").havenText(.sectionHead, color: theme.ctaInk)
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                    .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            }
            .accessibilityIdentifier("migraine-save")
            if existing?.had == true {
                Button { Task { await onRemove(); dismiss() } } label: {
                    Text("Remove migraine").havenText(.meta, color: theme.factorHigh)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
                }
            }
        }
        .padding(Spacing.s6)
    }
}
