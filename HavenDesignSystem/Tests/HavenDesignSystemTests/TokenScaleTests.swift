import Testing
import CoreGraphics
import CoreText
@testable import HavenDesignSystem

@Suite struct TokenScaleTests {
    @Test func spacingMatchesScale() {
        #expect(Spacing.s1 == 4)
        #expect(Spacing.s6 == 16)
        #expect(Spacing.s10 == 30)
    }
    @Test func radiiMatchScale() {
        #expect(Radius.xs == 8)
        #expect(Radius.lg == 18)
        #expect(Radius.xxl == 26)
        #expect(Radius.pill == 999)
    }
    @Test func typeScaleMatchesSource() {
        #expect(TypeScale.title == 34)
        #expect(TypeScale.display == 31)
        #expect(TypeScale.base == 13.5)
        #expect(TypeScale.sm == 12.5)
    }
    @Test func leadingAndTrackingMatchSource() {
        #expect(Leading.tight == 1.06)
        #expect(Tracking.wide == 0.14)
        #expect(Tracking.tight == -0.015)
    }
    @Test func fontFamilyExposesRegisteredNames() {
        #expect(FontFamily.serif.fontName(weight: .regular) == "Source Serif 4")
        #expect(FontFamily.sans.fontName(weight: .semibold) == "Hanken Grotesk")
    }

    /// Guards the real bug: the names must actually resolve to the bundled fonts.
    /// A wrong name (the previous "SourceSerif4"/"HankenGrotesk") silently falls
    /// back to the system font instead of throwing — only a resolution check catches it.
    @Test func fontNamesResolveToBundledFamilies() {
        Fonts.registerIfNeeded()
        for (family, expected) in [(FontFamily.serif, "Source Serif 4"), (FontFamily.sans, "Hanken Grotesk")] {
            let name = family.fontName(weight: .regular)
            let ct = CTFontCreateWithName(name as CFString, 16, nil)
            #expect(CTFontCopyFamilyName(ct) as String == expected, "\(name) did not resolve to \(expected)")
        }
    }
}
