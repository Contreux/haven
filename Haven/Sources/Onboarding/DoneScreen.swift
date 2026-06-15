import SwiftUI
import HavenDesignSystem

struct DoneScreen: View {
    @Environment(\.theme) private var theme
    let onEnter: () -> Void
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: Spacing.s5) {
                Spacer()
                Image(systemName: "checkmark.circle.fill").imageScale(.large).foregroundStyle(theme.accent)
                Text("You're all set").havenText(.screenTitle, color: theme.ink)
                Text("Let's log your first day and start building the picture.").havenText(.body, color: theme.inkSoft).multilineTextAlignment(.center)
                Spacer()
                Button(action: onEnter) { Text("Enter Haven").havenText(.sectionHead, color: theme.ctaInk).frame(maxWidth: .infinity).padding(.vertical, Spacing.s5).background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg)) }.accessibilityIdentifier("ob-enter")
            }.padding(Spacing.s7)
        }
    }
}
