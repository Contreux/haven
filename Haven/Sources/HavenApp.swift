import SwiftUI
import HavenDesignSystem

@main
struct HavenApp: App {
    @State private var themeController = ThemeController()

    init() { Fonts.registerIfNeeded() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.theme, themeController.theme)
                .environment(themeController)
        }
    }
}
