import Testing
@testable import HavenCore

@Suite struct CalendarMonthTests {
    @Test func buildsGridWithLeadingBlanks() {
        // June 2026: June 1 is a Monday → 1 leading blank (Sunday-start grid).
        let m = CalendarMonth.build(days: [], year: 2026, month: 6, today: "2026-06-15")
        #expect(m.cells.first?.day == nil)               // leading blank
        let dayCells = m.cells.filter { $0.day != nil }
        #expect(dayCells.count == 30)                    // June has 30 days
        #expect(dayCells.first?.day == 1)
        #expect(dayCells.last?.day == 30)
    }
    @Test func marksMigraineFoodSymptomsAndToday() {
        let days = [
            DayLog(userId: "d", date: "2026-06-10", factors: nil, factorsLoggedAt: nil,
                   migraine: Migraine(had: true, severity: "Severe", time: "12:00", notes: ""),
                   symptoms: [], symptomsLoggedAt: nil, foods: [FoodEntry(name: "X", time: "12:00", triggers: [])]),
            DayLog(userId: "d", date: "2026-06-11", factors: nil, factorsLoggedAt: nil, migraine: nil,
                   symptoms: ["light"], symptomsLoggedAt: "12:00", foods: []),
        ]
        let m = CalendarMonth.build(days: days, year: 2026, month: 6, today: "2026-06-15")
        let d10 = m.cells.first { $0.day == 10 }!
        #expect(d10.migraineSeverity == "Severe")
        #expect(d10.mark == .food)
        let d11 = m.cells.first { $0.day == 11 }!
        #expect(d11.migraineSeverity == nil)
        #expect(d11.mark == .symptoms)
        #expect(m.cells.first { $0.day == 15 }!.isToday)
    }
}
