import Testing
@testable import HavenCore

@Suite struct DoctorReportTests {
    private func day(_ date: String, migraine: Bool) -> DayLog {
        DayLog(userId: "u", date: date,
               factors: Factors(sleepHours: 7, stress: .mid, hydration: .mid, weatherSensitive: false),
               factorsLoggedAt: "09:00",
               migraine: migraine ? Migraine(had: true, severity: "moderate", time: "15:00", notes: "x") : nil,
               symptoms: migraine ? ["nausea"] : [], symptomsLoggedAt: migraine ? "15:00" : nil,
               foods: [FoodEntry(name: "Coffee", time: "08:00", triggers: [])])
    }
    @Test func headerHasClassRangeAndCount() {
        let text = DoctorReport.text(days: [day("2026-06-01", migraine: true), day("2026-06-03", migraine: false)],
                                     klass: "Episodic migraine with aura")
        #expect(text.contains("Episodic migraine with aura"))
        #expect(text.contains("2026-06-01"))
        #expect(text.contains("2026-06-03"))
        #expect(text.contains("1 migraine"))
    }
    @Test func emptyDaysStillProducesHeader() {
        let text = DoctorReport.text(days: [], klass: "Episodic migraine")
        #expect(text.contains("Episodic migraine"))
        #expect(text.contains("0 migraine"))
    }
    @Test func listsAttackDaysWithSeverity() {
        let text = DoctorReport.text(days: [day("2026-06-01", migraine: true)], klass: "k")
        #expect(text.contains("2026-06-01") && text.contains("moderate"))
    }
}
