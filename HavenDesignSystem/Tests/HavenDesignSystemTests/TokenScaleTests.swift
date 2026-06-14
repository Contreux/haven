import Testing
import CoreGraphics
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
    @Test func fontFamilyExposesPostScriptNames() {
        #expect(FontFamily.serif.fontName(weight: .regular) == "SourceSerif4")
        #expect(FontFamily.sans.fontName(weight: .semibold) == "HankenGrotesk")
    }
}
