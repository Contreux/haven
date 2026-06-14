import SwiftUI
import HavenDesignSystem

struct ActionButtons: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s4) {
            primary("Log a migraine", icon: "bolt.heart")
            ghost("Snap a meal", icon: "camera")
        }
    }

    private func primary(_ title: String, icon: String) -> some View {
        Button { /* wired in M2 */ } label: {
            Label(title, systemImage: icon)
                .havenText(.sectionHead, color: theme.ctaInk)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
        }
    }
    private func ghost(_ title: String, icon: String) -> some View {
        Button { /* wired in M2 */ } label: {
            Label(title, systemImage: icon)
                .havenText(.sectionHead, color: theme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(theme.hairline, lineWidth: 1))
        }
    }
}
