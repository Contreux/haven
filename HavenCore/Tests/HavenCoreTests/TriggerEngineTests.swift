import Testing
@testable import HavenCore

@Suite struct TriggerEngineTests {
    @Test func detectsAgedCheeseHigh() {
        let r = TriggerEngine.analyze("aged cheddar toastie")
        #expect(r.triggers.contains { $0.label == "Aged cheese" && $0.level == .high })
    }
    @Test func cleanFoodHasNoTriggers() {
        let r = TriggerEngine.analyze("grilled chicken salad")
        #expect(r.triggers.isEmpty)
    }
    @Test func ordersHighBeforeLow() {
        let r = TriggerEngine.analyze("red wine and dark chocolate") // alcohol high, chocolate mid
        #expect(r.triggers.first?.level == .high)
    }
    @Test func labelIsCapitalizedAndTrimmed() {
        let r = TriggerEngine.analyze("  pepperoni pizza  ")
        #expect(r.label == "Pepperoni pizza")
    }
}
