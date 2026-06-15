import SwiftUI
import HavenDesignSystem

struct ActionButtons: View {
    @Environment(\.theme) private var theme
    let onLogMigraine: () -> Void
    let onSnapMeal: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s4) {
            primary("Log a migraine", icon: "bolt.heart", action: onLogMigraine)
            ghost("Snap a meal", icon: "camera", action: onSnapMeal)
        }
    }
    private func primary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).havenText(.sectionHead, color: theme.ctaInk)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
        }
        .accessibilityIdentifier("log-migraine")
    }
    private func ghost(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).havenText(.sectionHead, color: theme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(theme.hairline, lineWidth: 1))
        }
        .accessibilityIdentifier("snap-meal")
    }
}
