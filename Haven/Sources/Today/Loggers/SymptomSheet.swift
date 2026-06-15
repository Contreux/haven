import SwiftUI
import HavenDesignSystem
import HavenCore

struct SymptomOption: Identifiable { let id: String; let label: String; let icon: String }

struct SymptomSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let existing: [String]
    let onSave: ([String]) async -> Void

    static let catalog: [SymptomOption] = [
        .init(id: "light", label: "Light / glare", icon: "sun.max"),
        .init(id: "eye", label: "Eye strain", icon: "eye"),
        .init(id: "neck", label: "Neck pain", icon: "figure.stand"),
        .init(id: "back", label: "Back pain", icon: "figure.walk"),
        .init(id: "nausea", label: "Nausea", icon: "exclamationmark.bubble"),
        .init(id: "sound", label: "Sound sensitivity", icon: "speaker.wave.2"),
    ]

    @State private var selected: Set<String>
    init(existing: [String], onSave: @escaping ([String]) async -> Void) {
        self.existing = existing; self.onSave = onSave
        _selected = State(initialValue: Set(existing))
    }

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                SheetHeader(title: "Log symptoms", subtitle: "Tap all that apply")
                LazyVGrid(columns: cols, spacing: Spacing.s3) {
                    ForEach(Self.catalog) { opt in
                        let on = selected.contains(opt.id)
                        Button {
                            if on { selected.remove(opt.id) } else { selected.insert(opt.id) }
                        } label: {
                            HStack(spacing: Spacing.s2) {
                                Image(systemName: opt.icon)
                                Text(opt.label).havenText(.meta, color: on ? theme.ctaInk : theme.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.s4)
                            .background(on ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                            .foregroundStyle(on ? theme.ctaInk : theme.inkSoft)
                        }
                    }
                }
                Button {
                    Task { await onSave(Array(selected)); dismiss() }
                } label: {
                    Text("Save").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                .accessibilityIdentifier("symptoms-save")
                Spacer()
            }
            .padding(Spacing.s6)
        }
    }
}
