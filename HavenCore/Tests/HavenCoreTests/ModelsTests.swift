import Testing
import Foundation
@testable import HavenCore

@Suite struct ModelsTests {
    static let dayJSON = """
    {
      "_id": "abc", "_creationTime": 1.0,
      "userId": "sim-device", "date": "2026-06-14",
      "factors": { "sleepHours": 6.5, "stress": "high", "hydration": "low", "weatherSensitive": true },
      "factorsLoggedAt": "09:02",
      "migraine": { "had": true, "severity": "moderate", "time": "15:10", "notes": "left eye" },
      "symptoms": ["nausea", "aura"], "symptomsLoggedAt": "14:40",
      "foods": [
        { "name": "Aged cheddar", "time": "12:30", "triggers": [ { "label": "Tyramine", "level": "high" } ] }
      ]
    }
    """

    @Test func decodesFullDay() throws {
        let day = try JSONDecoder().decode(DayLog.self, from: Data(Self.dayJSON.utf8))
        #expect(day.date == "2026-06-14")
        #expect(day.factors?.sleepHours == 6.5)
        #expect(day.factors?.stress == .high)
        #expect(day.migraine?.had == true)
        #expect(day.symptoms == ["nausea", "aura"])
        #expect(day.symptomsLoggedAt == "14:40")
        #expect(day.foods.first?.triggers.first?.level == .high)
    }

    @Test func decodesSparseDay() throws {
        let json = #"{ "userId": "d", "date": "2026-06-11", "symptoms": [], "foods": [] }"#
        let day = try JSONDecoder().decode(DayLog.self, from: Data(json.utf8))
        #expect(day.factors == nil)
        #expect(day.migraine == nil)
        #expect(day.symptoms.isEmpty)
        #expect(day.foods.isEmpty)
    }

    @Test func levelDecodesFromString() throws {
        #expect(try JSONDecoder().decode(Level.self, from: Data("\"mid\"".utf8)) == .mid)
    }
}
