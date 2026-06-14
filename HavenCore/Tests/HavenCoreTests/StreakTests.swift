import Testing
@testable import HavenCore

@Suite struct StreakTests {
    @Test func countsConsecutiveDaysEndingToday() {
        let dates = ["2026-06-14", "2026-06-13", "2026-06-12"]
        #expect(streak(loggedDates: dates, asOf: "2026-06-14") == 3)
    }
    @Test func stopsAtFirstGap() {
        let dates = ["2026-06-14", "2026-06-13", "2026-06-11"] // 12th missing
        #expect(streak(loggedDates: dates, asOf: "2026-06-14") == 2)
    }
    @Test func zeroWhenTodayMissing() {
        #expect(streak(loggedDates: ["2026-06-13"], asOf: "2026-06-14") == 0)
    }
}
