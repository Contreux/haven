import Testing
@testable import HavenDesignSystem

@Suite struct PrimitivesTests {
    @Test func brandOrangeMatchesSource() {
        #expect(Primitives.orange500 == RGBA(hex: 0xef6a20))
        #expect(Primitives.orange600 == RGBA(hex: 0xec6a1e))
        #expect(Primitives.orangeInk == RGBA(hex: 0x1c0f06))
    }
    @Test func neutralsMatchSource() {
        #expect(Primitives.charcoal900 == RGBA(hex: 0x1c1712))
        #expect(Primitives.cream100 == RGBA(hex: 0xf3ece3))
        #expect(Primitives.paper50 == RGBA(hex: 0xf1ece4))
    }
    @Test func factorHuesMatchSource() {
        #expect(Primitives.sageDark == RGBA(hex: 0x8a9966))
        #expect(Primitives.amberDark == RGBA(hex: 0xd79a4e))
        #expect(Primitives.clayDark == RGBA(hex: 0xcf7551))
    }
}
