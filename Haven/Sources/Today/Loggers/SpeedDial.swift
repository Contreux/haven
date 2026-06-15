import SwiftUI
import HavenDesignSystem

enum LoggerKind: String, Identifiable { case food, migraine, symptom, factors; var id: String { rawValue } }

struct SpeedDial: View {
    @Environment(\.theme) private var theme
    @Binding var isOpen: Bool
    let onPick: (LoggerKind) -> Void

    private let items: [(LoggerKind, String, String)] = [
        (.food, "Food", "camera"),
        (.migraine, "Migraine", "bolt.heart"),
        (.symptom, "Symptom", "eye"),
        (.factors, "Daily factors", "moon"),
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isOpen {
                Color.clear.contentShape(Rectangle()).ignoresSafeArea().onTapGesture { isOpen = false }
            }
            VStack(alignment: .trailing, spacing: Spacing.s3) {
                if isOpen {
                    ForEach(items, id: \.0.id) { kind, label, icon in
                        Button { isOpen = false; onPick(kind) } label: {
                            HStack(spacing: Spacing.s2) {
                                Text(label).havenText(.meta, color: theme.ink)
                                Image(systemName: icon).foregroundStyle(theme.accent)
                            }
                            .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s3)
                            .background(theme.surface, in: Capsule())
                        }
                        .accessibilityIdentifier("dial-\(kind.rawValue)")
                    }
                }
                Button { isOpen.toggle() } label: {
                    Image(systemName: "plus").rotationEffect(.degrees(isOpen ? 45 : 0))
                        .foregroundStyle(theme.ctaInk).font(.title2)
                        .frame(width: 56, height: 56).background(theme.ctaBg, in: Circle())
                }
                .accessibilityIdentifier("speed-dial")
            }
        }
    }
}
