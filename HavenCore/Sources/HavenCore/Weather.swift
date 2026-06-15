import Foundation

public struct Weather: Codable, Sendable, Equatable {
    public let level: Level          // reuses the factor color mapping in the UI
    public let bars: Int             // 1...4 gauge fill
    public let swing: Int            // pressure swing (hPa)
    public let tempSwing: Int        // °, magnitude of change
    public let humidity: Int         // %
    public let temp: Int             // current °
    public let trend: String         // contract: "rising" | "falling" | "steady" (stub emits rising/falling only)
    public let headline: String
    public let detail: String
    public let pressureTrend: [Double]

    public init(level: Level, bars: Int, swing: Int, tempSwing: Int, humidity: Int, temp: Int, trend: String, headline: String, detail: String, pressureTrend: [Double]) {
        self.level = level
        self.bars = bars
        self.swing = swing
        self.tempSwing = tempSwing
        self.humidity = humidity
        self.temp = temp
        self.trend = trend
        self.headline = headline
        self.detail = detail
        self.pressureTrend = pressureTrend
    }
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
        let pressureTrend = (0..<8).map { i in 1015.0 - Double((seed + i) % 6) - Double(i) * 0.4 }
        return Weather(
            level: level, bars: bars, swing: bars * 3,
            tempSwing: 4 + (seed % 6), humidity: 55 + (seed % 30),
            temp: 14 + (seed % 12), trend: seed % 2 == 0 ? "falling" : "rising",
            headline: headline, detail: detail, pressureTrend: pressureTrend)
    }
}
