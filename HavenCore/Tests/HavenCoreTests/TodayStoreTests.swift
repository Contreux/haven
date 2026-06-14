import Testing
@testable import HavenCore

@MainActor
final class FakeSource: DayDataSource {
    var day: DayLog?
    var onChange: ((DayLog?) -> Void)?
    private(set) var setFactorsCalls: [(date: String, factors: Factors, at: String)] = []

    init(day: DayLog?) { self.day = day }

    func observeDay(date: String, onChange: @escaping (DayLog?) -> Void) {
        self.onChange = onChange
        onChange(day)
    }
    func setFactors(date: String, factors: Factors, loggedAt: String) async throws {
        setFactorsCalls.append((date, factors, loggedAt))
        let prev = day
        day = DayLog(userId: "d", date: date, factors: factors, factorsLoggedAt: loggedAt,
                     migraine: prev?.migraine, symptoms: prev?.symptoms ?? [],
                     symptomsLoggedAt: prev?.symptomsLoggedAt, foods: prev?.foods ?? [])
        onChange?(day)   // simulate Convex pushing the update back
    }
}

@Suite @MainActor struct TodayStoreTests {
    @Test func loadsInitialDayAndBuildsLedger() {
        let d = DayLog(userId: "d", date: "2026-06-14",
                       factors: Factors(sleepHours: 6.5, stress: .high, hydration: .low, weatherSensitive: true),
                       factorsLoggedAt: "09:02", migraine: nil, symptoms: [], symptomsLoggedAt: nil,
                       foods: [FoodEntry(name: "A", time: "08:00", triggers: [])])
        let store = TodayStore(source: FakeSource(day: d), today: "2026-06-14")
        store.start()
        #expect(store.day?.date == "2026-06-14")
        #expect(store.ledger.count == 2)               // factors + 1 food
        #expect(store.weather.headline.isEmpty == false)
    }

    @Test func editingFactorsWritesAndReflectsReactively() async throws {
        let source = FakeSource(day: DayLog(userId: "d", date: "2026-06-14", factors: nil,
                                            factorsLoggedAt: nil, migraine: nil, symptoms: [],
                                            symptomsLoggedAt: nil, foods: []))
        let store = TodayStore(source: source, today: "2026-06-14")
        store.start()
        try await store.saveFactors(Factors(sleepHours: 8, stress: .low, hydration: .mid, weatherSensitive: false),
                                     at: "10:15")
        #expect(source.setFactorsCalls.count == 1)
        #expect(store.day?.factors?.sleepHours == 8)   // pushed back through observeDay
        #expect(store.ledger.contains { $0.kind == .factors })
    }
}
