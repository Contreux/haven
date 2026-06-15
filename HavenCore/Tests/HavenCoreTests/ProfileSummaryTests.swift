import Testing
@testable import HavenCore

@Suite struct ProfileSummaryTests {
    @Test func mapsSingleSelectToOptionLabel() {
        let rows = profileRows(answers: ["frequency": ["weekly"]])
        let freq = rows.first { $0.questionId == "frequency" }
        #expect(freq?.value == "Around 1 day a week")
        #expect(freq?.title == "Frequency")
    }
    @Test func joinsMultiSelectLabels() {
        let rows = profileRows(answers: ["triggers": ["food", "alcohol"]])
        let trig = rows.first { $0.questionId == "triggers" }
        #expect(trig?.value == "Certain foods, Alcohol")
    }
    @Test func omitsUnansweredQuestions() {
        let rows = profileRows(answers: ["frequency": ["weekly"]])
        #expect(rows.allSatisfy { $0.questionId != "aura" })
    }
    @Test func hidesCycleWhenSexNotApplicable() {
        let rows = profileRows(answers: ["sex": ["male"], "cycle": ["track"]])
        #expect(rows.allSatisfy { $0.questionId != "cycle" })
    }
    @Test func showsCycleWhenFemale() {
        let rows = profileRows(answers: ["sex": ["female"], "cycle": ["track"]])
        #expect(rows.contains { $0.questionId == "cycle" })
    }
    @Test func rowsFollowCatalogOrder() {
        let rows = profileRows(answers: ["aura": ["no"], "frequency": ["weekly"]])
        #expect(rows.map(\.questionId) == ["frequency", "aura"])
    }
}
