import Testing
@testable import HavenCore

@Suite struct WeatherStubTests {
    @Test func stubIsDeterministicForADate() {
        let a = WeatherStub.weather(for: "2026-06-14")
        let b = WeatherStub.weather(for: "2026-06-14")
        #expect(a == b)
    }
    @Test func barsMatchLevel() {
        let w = WeatherStub.weather(for: "2026-06-14")
        #expect(w.bars >= 1 && w.bars <= 4)
        switch w.level {
        case .low: #expect(w.bars <= 2)
        case .mid: #expect(w.bars == 3)
        case .high: #expect(w.bars == 4)
        }
    }
    @Test func headlineNonEmpty() {
        #expect(WeatherStub.weather(for: "2026-06-14").headline.isEmpty == false)
    }
}
