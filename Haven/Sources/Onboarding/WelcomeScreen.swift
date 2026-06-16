import SwiftUI
import HavenDesignSystem

struct WelcomeScreen: View {
    @Environment(\.theme) private var theme
    let onStart: () -> Void
    let onSignIn: () -> Void
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Spacer()
                Image(systemName: "flame.fill").imageScale(.large).foregroundStyle(theme.accent)
                Text("Find what's been triggering your migraines.").havenText(.screenTitle, color: theme.ink)
                Text("Haven turns your daily logs — meals, weather, sleep — into a clear, personal picture of what sets your attacks off.").havenText(.body, color: theme.inkSoft)
                Spacer()
                Button(action: onStart) {
                    Text("Get started").havenText(.sectionHead, color: theme.ctaInk).primaryCTA()
                }.accessibilityIdentifier("ob-start")
                Button(action: onSignIn) { Text("I already have an account").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity) }
            }.padding(Spacing.s7)
        }
    }
}
