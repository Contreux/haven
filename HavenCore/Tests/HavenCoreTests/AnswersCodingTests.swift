import Testing
import Foundation
@testable import HavenCore

@Suite struct AnswersCodingTests {
    @Test func roundTripsSingleAndMulti() {
        let dict = ["frequency": ["weekly"], "triggers": ["food", "alcohol"]]
        let json = answersJSON(from: dict)
        #expect(answersDict(from: json) == dict)
    }
    @Test func emptyJSONDecodesToEmpty() {
        #expect(answersDict(from: "") == [:])
        #expect(answersDict(from: "{}") == [:])
    }
    @Test func settingsDecodesAnswersAndReminderAndCoords() throws {
        let json = """
        {"theme":"dark","onboarded":true,"subscribed":false,
         "answers":"{\\"frequency\\":[\\"weekly\\"]}","reminderTime":"evening","lat":51.5,"lon":-0.1}
        """.data(using: .utf8)!
        let s = try JSONDecoder().decode(Settings.self, from: json)
        #expect(s.reminderTime == "evening")
        #expect(s.lat == 51.5)
        #expect(answersDict(from: s.answers) == ["frequency": ["weekly"]])
    }
}
