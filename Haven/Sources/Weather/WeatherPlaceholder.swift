import SwiftUI
import HavenDesignSystem

struct WeatherPlaceholder: View {
    @Environment(\.theme) private var theme
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: Spacing.s4) {
                Image(systemName: "cloud.sun").imageScale(.large).foregroundStyle(theme.inkFaint)
                Text("Weather").havenText(.sectionHead, color: theme.ink)
                Text("Barometric pressure risk is coming soon.").havenText(.body, color: theme.inkSoft)
            }.padding(Spacing.s7)
        }
    }
}
