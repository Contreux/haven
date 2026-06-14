import Testing
@testable import HavenDesignSystem

@Suite struct RGBATests {
    @Test func decodesSixDigitHex() {
        let c = RGBA(hex: 0xef6a20)
        #expect(c.r == 0xef / 255.0)
        #expect(c.g == 0x6a / 255.0)
        #expect(c.b == 0x20 / 255.0)
        #expect(c.a == 1.0)
    }

    @Test func appliesAlpha() {
        let c = RGBA(hex: 0xef6a20, alpha: 0.14)
        #expect(c.a == 0.14)
    }

    @Test func equalityIsValueBased() {
        #expect(RGBA(hex: 0x112233) == RGBA(hex: 0x112233))
        #expect(RGBA(hex: 0x112233) != RGBA(hex: 0x112234))
    }
}
