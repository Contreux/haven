import Testing
@testable import HavenDesignSystem

@Suite struct ThemeTests {
    @Test func darkMapsPrimitivesPerSource() {
        let t = Theme.dark
        #expect(t.bgToken == Primitives.charcoal900)
        #expect(t.surfaceToken == Primitives.charcoal820)
        #expect(t.inkToken == Primitives.cream100)
        #expect(t.accentToken == Primitives.orange500)
        #expect(t.factorHighToken == Primitives.clayDark)
    }
    @Test func lightMapsPrimitivesPerSource() {
        let t = Theme.light
        #expect(t.bgToken == Primitives.paper50)
        #expect(t.inkToken == Primitives.ink900)
        #expect(t.accentToken == Primitives.orange600)
        #expect(t.ctaBgToken == Primitives.ink700)
        #expect(t.factorHighToken == Primitives.clayLight)
    }
    @Test func factorColorMapsLevels() {
        let t = Theme.dark
        #expect(t.factorColorToken(for: .high) == Primitives.clayDark)
        #expect(t.factorColorToken(for: .medium) == Primitives.amberDark)
        #expect(t.factorColorToken(for: .low) == Primitives.sageDark)
    }
}
