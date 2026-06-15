import Testing
import Foundation
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
    @Test func weatherDecodesActionShape() throws {
        let json = #"{"level":"high","bars":3,"swing":9,"tempSwing":7,"humidity":71,"temp":17,"trend":"falling","headline":"Pressure dropping 9 hPa","detail":"with a 7° swing","pressureTrend":[1015.6,1014.9,1013.2,1011.5]}"#
        let w = try JSONDecoder().decode(Weather.self, from: Data(json.utf8))
        #expect(w.swing == 9)
        #expect(w.level == .high)
        #expect(w.pressureTrend.count == 4)
    }
    @Test func stubPopulatesSwingAndTrend() {
        let w = WeatherStub.weather(for: "2026-06-15")
        #expect(w.swing >= 0)
        #expect(w.pressureTrend.isEmpty == false)
    }
}
