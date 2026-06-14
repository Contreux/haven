import SwiftUI
import HavenDesignSystem

struct RootView: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeController.self) private var controller

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("FOUNDATION")
                    .havenText(.eyebrow, color: theme.inkFaint)
                Text("Haven")
                    .havenText(.screenTitle, color: theme.ink)
                Text("Every value on this screen comes from a design token.")
                    .havenText(.body, color: theme.inkSoft)

                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(theme.surface)
                    .frame(height: 96)
                    .overlay(
                        Text("Elevated").havenText(.riskWord, color: theme.risk)
                    )

                Button {
                    controller.toggle()
                } label: {
                    Text(controller.mode == .dark ? "Switch to light" : "Switch to dark")
                        .havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                .accessibilityIdentifier("theme-toggle")
            }
            .padding(Spacing.s6)
        }
    }
}
