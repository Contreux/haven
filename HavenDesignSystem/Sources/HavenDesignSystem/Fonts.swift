import CoreText
import Foundation

public enum Fonts {
    /// Registers bundled fonts. Call once at app launch. Idempotent.
    public static func registerIfNeeded() {
        for name in ["SourceSerif4", "HankenGrotesk"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                    ?? Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
