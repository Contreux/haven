import Foundation

public struct Weather: Sendable, Equatable {
    public let level: Level          // reuses the factor color mapping in the UI
    public let bars: Int             // 1...4 gauge fill
    public let tempSwing: Int        // °, magnitude of change
    public let humidity: Int         // %
    public let temp: Int             // current °
    public let trend: String         // contract: "rising" | "falling" | "steady" (stub emits rising/falling only)
    public let headline: String
    public let detail: String
}

/// Deterministic mock matching the real `fetchWeather` contract (swapped in M4).
public enum WeatherStub {
    public static func weather(for date: String) -> Weather {
        // Deterministic pseudo-random from the date string.
        let seed = date.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let levels: [Level] = [.low, .mid, .high]
        let level = levels[seed % 3]
        let bars: Int
        let headline: String
        let detail: String
        switch level {
        case .low:
            bars = 2; headline = "Calm pressure"
            detail = "Stable barometric pressure today — low trigger risk."
        case .mid:
            bars = 3; headline = "Shifting front"
            detail = "Moderate pressure swing this afternoon."
        case .high:
            bars = 4; headline = "Storm incoming"
            detail = "Sharp pressure drop expected — elevated migraine risk."
        }
        return Weather(
            level: level, bars: bars,
            tempSwing: 4 + (seed % 6), humidity: 55 + (seed % 30),
            temp: 14 + (seed % 12), trend: seed % 2 == 0 ? "falling" : "rising",
            headline: headline, detail: detail
        )
    }
}
