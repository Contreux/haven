import Testing
import Foundation
@testable import HavenCore

@Suite struct AnalyzedFoodTests {
    @Test func decodesWithItems() throws {
        let json = #"{"label":"Burger meal","items":["Cheeseburger","Fries"],"triggers":[],"note":"ok"}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(AnalyzedFood.self, from: json)
        #expect(a.items == ["Cheeseburger", "Fries"])
    }
    @Test func toleratesMissingItems() throws {
        let json = #"{"label":"x","triggers":[],"note":""}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(AnalyzedFood.self, from: json)
        #expect(a.items == [])
    }
    @Test func triggerEngineReturnsEmptyItems() {
        #expect(TriggerEngine.analyze("red wine and brie").items == [])
    }
}
