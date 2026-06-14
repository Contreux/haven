import SwiftUI
import Observation

public enum ThemeMode: String, Sendable { case dark, light }

@MainActor @Observable
public final class ThemeController {
    public var mode: ThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.key) }
    }
    public var theme: Theme { mode == .light ? .light : .dark }

    private static let key = "haven.theme"

    public init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        self.mode = ThemeMode(rawValue: raw ?? "") ?? .dark   // dark default
    }

    public func toggle() { mode = (mode == .dark) ? .light : .dark }
}
