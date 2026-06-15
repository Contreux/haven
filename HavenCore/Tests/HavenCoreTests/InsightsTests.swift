import Testing
@testable import HavenCore

@Suite struct InsightsTests {
    func day(date: String, migraine: Bool, foods: [FoodEntry] = [], symptoms: [String] = [], factors: Factors? = nil) -> DayLog {
        DayLog(userId: "d", date: date,
               factors: factors, factorsLoggedAt: factors == nil ? nil : "09:00",
               migraine: migraine ? Migraine(had: true, severity: "Moderate", time: "12:00", notes: "") : nil,
               symptoms: symptoms, symptomsLoggedAt: symptoms.isEmpty ? nil : "12:00", foods: foods)
    }
    func food(_ name: String, _ trig: [TriggerChip]) -> FoodEntry { FoodEntry(name: name, time: "12:00", triggers: trig) }

    @Test func countsDaysAndTriggers() {
        let cheese = TriggerChip(label: "Aged cheese", level: .high, reason: "tyramine")
        let days = [
            day(date: "2026-06-10", migraine: true, foods: [food("Cheddar", [cheese])]),
            day(date: "2026-06-11", migraine: false, foods: [food("Cheddar", [cheese])]),
            day(date: "2026-06-12", migraine: false, symptoms: ["light"]),
        ]
        let r = Insights.compute(days)
        #expect(r.migraineDays == 1)
        #expect(r.trackedDays == 3)
        #expect(r.triggersSeen == 1)
        let cheeseStat = r.ranked.first { $0.name == "Aged cheese" }
        #expect(cheeseStat?.total == 2)
        #expect(cheeseStat?.onMigraine == 1)
    }

    @Test func ranksByMigraineOverlapThenTotal() {
        let cheese = TriggerChip(label: "Aged cheese", level: .high)
        let wine = TriggerChip(label: "Alcohol", level: .high)
        let days = [
            day(date: "2026-06-10", migraine: true, foods: [food("Wine", [wine])]),
            day(date: "2026-06-11", migraine: false, foods: [food("Cheddar", [cheese]), food("Cheese2", [cheese])]),
        ]
        let r = Insights.compute(days)
        #expect(r.ranked.first?.name == "Alcohol")     // onMigraine 1 > 0
    }

    @Test func emptyWhenNoData() {
        let r = Insights.compute([])
        #expect(r.migraineDays == 0 && r.trackedDays == 0 && r.triggersSeen == 0 && r.ranked.isEmpty)
    }
}
