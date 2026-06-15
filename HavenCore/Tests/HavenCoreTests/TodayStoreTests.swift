import Testing
import Foundation
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

    private(set) var savedMigraine: Migraine?
    private(set) var savedSymptoms: [String]?
    private(set) var savedFoods: [FoodEntry] = []
    var analyzeResult: AnalyzedFood = AnalyzedFood(label: "X", triggers: [], note: "n")
    var analyzeShouldThrow = false

    func setMigraine(date: String, migraine: Migraine) async throws {
        savedMigraine = migraine
        let prev = day
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: migraine, symptoms: prev?.symptoms ?? [], symptomsLoggedAt: prev?.symptomsLoggedAt, foods: prev?.foods ?? [])
        onChange?(day)
    }
    func removeMigraine(date: String) async throws {
        savedMigraine = nil
        let prev = day
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: nil, symptoms: prev?.symptoms ?? [], symptomsLoggedAt: prev?.symptomsLoggedAt, foods: prev?.foods ?? [])
        onChange?(day)
    }
    func setSymptoms(date: String, symptoms: [String], loggedAt: String) async throws {
        savedSymptoms = symptoms
        let prev = day
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: prev?.migraine, symptoms: symptoms, symptomsLoggedAt: loggedAt, foods: prev?.foods ?? [])
        onChange?(day)
    }
    func addFood(date: String, food: FoodEntry) async throws {
        savedFoods.append(food)
        let prev = day
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: prev?.migraine, symptoms: prev?.symptoms ?? [], symptomsLoggedAt: prev?.symptomsLoggedAt,
                     foods: (prev?.foods ?? []) + [food])
        onChange?(day)
    }
    func removeFood(date: String, foodIndex: Int) async throws {
        let prev = day
        var foods = prev?.foods ?? []
        if foods.indices.contains(foodIndex) { foods.remove(at: foodIndex) }
        day = DayLog(userId: "d", date: date, factors: prev?.factors, factorsLoggedAt: prev?.factorsLoggedAt,
                     migraine: prev?.migraine, symptoms: prev?.symptoms ?? [], symptomsLoggedAt: prev?.symptomsLoggedAt, foods: foods)
        onChange?(day)
    }
    func analyzeFood(description: String) async throws -> AnalyzedFood {
        if analyzeShouldThrow { throw NSError(domain: "x", code: 1) }
        return analyzeResult
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

    @Test func saveMigraineWritesAndReflects() async throws {
        let store = TodayStore(source: FakeSource(day: nil), today: "2026-06-14")
        store.start()
        try await store.saveMigraine(Migraine(had: true, severity: "Mild", time: "10:00", notes: ""))
        #expect(store.day?.migraine?.had == true)
        #expect(store.ledger.contains { $0.kind == .migraine })
    }
    @Test func saveFoodAppendsToLedger() async throws {
        let store = TodayStore(source: FakeSource(day: nil), today: "2026-06-14")
        store.start()
        try await store.saveFood(FoodEntry(name: "Wine", time: "20:00", triggers: []))
        #expect(store.ledger.contains { $0.kind == .food })
    }
    @Test func analyzeUsesActionThenFallsBack() async throws {
        let src = FakeSource(day: nil)
        src.analyzeResult = AnalyzedFood(label: "Cheese", triggers: [TriggerChip(label: "Aged cheese", level: .high)], note: "n")
        let store = TodayStore(source: src, today: "2026-06-14")
        let ok = await store.analyze("aged cheddar")
        #expect(ok.label == "Cheese")               // action path
        src.analyzeShouldThrow = true
        let fb = await store.analyze("aged cheddar") // falls back to on-device engine
        #expect(fb.triggers.contains { $0.label == "Aged cheese" })
    }
}
