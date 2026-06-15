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

    public func saveMigraine(_ migraine: Migraine) async throws {
        try await source.setMigraine(date: today, migraine: migraine)
    }
    public func removeMigraine() async throws { try await source.removeMigraine(date: today) }
    public func saveSymptoms(_ symptoms: [String], at time: String? = nil) async throws {
        try await source.setSymptoms(date: today, symptoms: symptoms, loggedAt: time ?? Self.nowHM())
    }
    public func saveFood(_ food: FoodEntry) async throws { try await source.addFood(date: today, food: food) }
    public func removeFood(at index: Int) async throws { try await source.removeFood(date: today, foodIndex: index) }

    /// Two-tier: try the server action; on any error fall back to the on-device engine.
    public func analyze(_ description: String) async -> AnalyzedFood {
        do { return try await source.analyzeFood(description: description) }
        catch { return TriggerEngine.analyze(description) }
    }
}
