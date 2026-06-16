import SwiftUI
import HavenDesignSystem

struct DoneScreen: View {
    @Environment(\.theme) private var theme
    let onEnter: () -> Void
    @State private var popped = false

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            // Soft accent glow behind the mark.
            RadialGradient(colors: [theme.accent.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 160)
                .frame(width: 320, height: 320)

            VStack(spacing: 0) {
                // Solid accent disc with a dark check, popping in on appear.
                ZStack {
                    Circle().fill(theme.accent).frame(width: 84, height: 84)
                        .shadow(color: theme.ctaShadow.swiftUIColor.opacity(0.45), radius: 16, x: 0, y: 8)
                    Image(systemName: "checkmark").font(.system(size: 36, weight: .bold)).foregroundStyle(theme.ctaInk)
                }
                .scaleEffect(popped ? 1 : 0.6)
                .padding(.bottom, Spacing.s8)

                Text("You're all set").havenText(.screenTitle, color: theme.ink)
                    .multilineTextAlignment(.center)
                Text("Your profile's saved. Let's log your first day and start building the picture.")
                    .havenText(.body, color: theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, Spacing.s5)

                Button(action: onEnter) {
                    Text("Enter Haven").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                .frame(maxWidth: 280)
                .padding(.top, Spacing.s10)
                .accessibilityIdentifier("ob-enter")
            }
            .padding(.horizontal, Spacing.s8)
        }
        .onAppear { withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) { popped = true } }
    }
}
