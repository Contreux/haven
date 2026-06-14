import Foundation
import Observation

@MainActor
@Observable
public final class TodayStore {
    public private(set) var day: DayLog?
    public private(set) var ledger: [LedgerEntry] = []
    public let weather: Weather
    public let today: String

    private let source: DayDataSource

    public init(source: DayDataSource, today: String) {
        self.source = source
        self.today = today
        self.weather = WeatherStub.weather(for: today)
    }

    public func start() {
        source.observeDay(date: today) { [weak self] day in
            guard let self else { return }
            self.day = day
            self.ledger = day.map(buildLedger(from:)) ?? []
        }
    }

    /// "HH:mm" for now — the ledger timestamp for a fresh edit.
    public static func nowHM(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }

    public func saveFactors(_ factors: Factors, at time: String? = nil) async throws {
        try await source.setFactors(date: today, factors: factors, loggedAt: time ?? Self.nowHM())
    }
}
