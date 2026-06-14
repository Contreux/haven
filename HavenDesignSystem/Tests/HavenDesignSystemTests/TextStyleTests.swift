import Testing
import CoreGraphics
@testable import HavenDesignSystem

@Suite struct TextStyleTests {
    @Test func screenTitleUsesSerifTitle() {
        let s = TextStyle.screenTitle
        #expect(s.family == .serif)
        #expect(s.size == TypeScale.title)
        #expect(s.trackingEm == Tracking.tight)
        #expect(s.leading == Leading.tight)
    }
    @Test func kerningIsTrackingTimesSize() {
        let s = TextStyle.eyebrow
        #expect(s.kerning == s.trackingEm * s.size)
    }
    @Test func lineSpacingDerivesFromLeading() {
        let s = TextStyle.body
        #expect(s.lineSpacing == s.size * (s.leading - 1))
    }
}
