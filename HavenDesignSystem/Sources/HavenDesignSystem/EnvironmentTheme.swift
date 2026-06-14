import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .dark
}

public extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
