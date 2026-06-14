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
}
