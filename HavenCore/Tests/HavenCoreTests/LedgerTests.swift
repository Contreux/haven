import Testing
@testable import HavenCore

@Suite struct LedgerTests {
    func day(
        factors: Factors? = nil, factorsAt: String? = nil,
        migraine: Migraine? = nil,
        symptoms: [String] = [], symptomsAt: String? = nil,
        foods: [FoodEntry] = []
    ) -> DayLog {
        DayLog(userId: "d", date: "2026-06-14", factors: factors, factorsLoggedAt: factorsAt,
               migraine: migraine, symptoms: symptoms, symptomsLoggedAt: symptomsAt, foods: foods)
    }

    @Test func emptyDayHasNoEntries() {
        #expect(buildLedger(from: day()).isEmpty)
    }

    @Test func mergesAllTypesSortedByTime() {
        let d = day(
            factors: Factors(sleepHours: 6.5, stress: .high, hydration: .low, weatherSensitive: true),
            factorsAt: "09:02",
            migraine: Migraine(had: true, severity: "moderate", time: "15:10", notes: "x"),
            symptoms: ["nausea"], symptomsAt: "14:40",
            foods: [FoodEntry(name: "Cheddar", time: "12:30", triggers: [])]
        )
        let entries = buildLedger(from: d)
        #expect(entries.map(\.time) == ["09:02", "12:30", "14:40", "15:10"])
        #expect(entries.first?.kind == .factors)
        #expect(entries.last?.kind == .migraine)
    }

    @Test func migraineExcludedWhenNotHad() {
        let d = day(migraine: Migraine(had: false, severity: "", time: "10:00", notes: ""))
        #expect(buildLedger(from: d).isEmpty)
    }

    @Test func symptomsExcludedWhenEmpty() {
        let d = day(symptoms: [], symptomsAt: "10:00")
        #expect(buildLedger(from: d).isEmpty)
    }

    @Test func factorsExcludedWhenTimestampMissing() {
        let d = day(factors: Factors(sleepHours: 7, stress: .low, hydration: .mid, weatherSensitive: false),
                    factorsAt: nil)
        #expect(buildLedger(from: d).isEmpty)
    }

    @Test func eachFoodIsItsOwnEntry() {
        let d = day(foods: [
            FoodEntry(name: "A", time: "08:00", triggers: []),
            FoodEntry(name: "B", time: "12:00", triggers: []),
        ])
        let entries = buildLedger(from: d)
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.kind == .food })
    }
}
