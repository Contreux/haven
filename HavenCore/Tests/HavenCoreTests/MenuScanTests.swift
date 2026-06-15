import Testing
import Foundation
@testable import HavenCore

@Suite struct MenuScanTests {
    @Test func decodesDishesTolerantly() throws {
        let json = """
        {"dishes":[
          {"name":"Pizza","verdict":"avoid","triggers":["aged cheese"],"reason":"tyramine"},
          {"name":"Salad","verdict":"safe"}
        ]}
        """
        let scan = try JSONDecoder().decode(MenuScan.self, from: Data(json.utf8))
        #expect(scan.dishes.count == 2)
        #expect(scan.dishes[0].verdict == .avoid)
        #expect(scan.dishes[0].triggers == ["aged cheese"])
        #expect(scan.dishes[1].verdict == .safe)
        #expect(scan.dishes[1].triggers.isEmpty)   // missing array -> []
        #expect(scan.dishes[1].reason.isEmpty)      // missing string -> ""
    }

    @Test func unknownVerdictDecodesToCaution() throws {
        let json = #"{"dishes":[{"name":"Mystery","verdict":"weird"}]}"#
        let scan = try JSONDecoder().decode(MenuScan.self, from: Data(json.utf8))
        #expect(scan.dishes[0].verdict == .caution)
    }

    @Test func groupedLeadsWithShorterList() {
        // 3 can-eat (safe/caution), 1 avoid -> lead with the avoid list
        let scan = MenuScan(dishes: [
            d("A", .safe), d("B", .caution), d("C", .safe), d("D", .avoid),
        ])
        let g = scan.grouped()
        #expect(g.canEat.count == 3)
        #expect(g.cantEat.count == 1)
        #expect(g.lead == .cantEat)
    }

    @Test func groupedLeadsWithCanEatWhenMoreAvoids() {
        let scan = MenuScan(dishes: [d("A", .safe), d("B", .avoid), d("C", .avoid)])
        #expect(scan.grouped().lead == .canEat)
    }

    @Test func groupedTieLeadsWithCanEat() {
        let scan = MenuScan(dishes: [d("A", .safe), d("B", .avoid)])
        #expect(scan.grouped().lead == .canEat)
    }

    @Test func asTriggerChipsMapsVerdictToLevel() {
        #expect(d("A", .avoid, ["cheese"]).asTriggerChips().first?.level == .high)
        #expect(d("A", .caution, ["nuts"]).asTriggerChips().first?.level == .mid)
        #expect(d("A", .safe, ["x"]).asTriggerChips().isEmpty)   // safe -> no chips
    }

    private func d(_ name: String, _ v: DishVerdict, _ t: [String] = []) -> MenuDish {
        MenuDish(name: name, verdict: v, triggers: t, reason: "")
    }
}
