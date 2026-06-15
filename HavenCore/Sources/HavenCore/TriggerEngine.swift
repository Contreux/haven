import Foundation

public struct AnalyzedFood: Codable, Sendable, Equatable {
    public let label: String
    public let triggers: [TriggerChip]
    public let note: String
    public init(label: String, triggers: [TriggerChip], note: String) {
        self.label = label; self.triggers = triggers; self.note = note
    }
}

/// Pure on-device keyword trigger engine (offline fallback for analyzeFood).
public enum TriggerEngine {
    private struct Rule { let pattern: String; let label: String; let level: Level; let reason: String }
    private static let rules: [Rule] = [
        Rule(pattern: "cheese|cheddar|parmesan|brie|blue|gouda|gruy|provolone", label: "Aged cheese", level: .high, reason: "High in tyramine"),
        Rule(pattern: "wine|beer|alcohol|cocktail|whiskey|prosecco|champagne|spirit", label: "Alcohol", level: .high, reason: "Common vasodilator trigger"),
        Rule(pattern: "salami|pepperoni|bacon|hot dog|deli|cured|sausage|ham|prosciutto|nitrate", label: "Cured meat", level: .high, reason: "Contains nitrates"),
        Rule(pattern: "msg|flavou?r enhancer|bouillon|stock cube", label: "MSG", level: .high, reason: "Flavor enhancer"),
        Rule(pattern: "soy sauce|tamari|fish sauce|miso", label: "Soy sauce", level: .mid, reason: "High-tyramine condiment"),
        Rule(pattern: "chocolate|cocoa|cacao", label: "Chocolate", level: .mid, reason: "Caffeine + phenylethylamine"),
        Rule(pattern: "coffee|espresso|caffeine|energy drink|cola|matcha|cold brew", label: "Caffeine", level: .mid, reason: "Excess or withdrawal can trigger"),
        Rule(pattern: "diet|aspartame|sweetener|sugar.?free|zero", label: "Artificial sweetener", level: .mid, reason: "Aspartame sensitivity"),
        Rule(pattern: "citrus|orange|lemon|lime|grapefruit", label: "Citrus", level: .low, reason: "Reported sensitivity in some"),
        Rule(pattern: "onion|garlic|pickle|kimchi|sauerkraut|fermented|yogurt|sourdough|yeast", label: "Fermented / yeast", level: .low, reason: "Histamine + tyramine content"),
        Rule(pattern: "nut|almond|peanut|walnut|pecan|cashew", label: "Nuts", level: .low, reason: "Possible trigger"),
        Rule(pattern: "tomato|marinara|ketchup|salsa", label: "Tomato", level: .low, reason: "Tomato-based foods"),
    ]

    public static func analyze(_ text: String) -> AnalyzedFood {
        let lower = text.lowercased()
        var found: [TriggerChip] = []
        for rule in rules {
            if lower.range(of: rule.pattern, options: .regularExpression) != nil,
               !found.contains(where: { $0.label == rule.label }) {
                found.append(TriggerChip(label: rule.label, level: rule.level, reason: rule.reason))
            }
        }
        let order: [Level: Int] = [.high: 0, .mid: 1, .low: 2]
        found.sort { (order[$0.level] ?? 3) < (order[$1.level] ?? 3) }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let cut = String(collapsed.prefix(42))
        let label = cut.isEmpty ? "Food" : cut.prefix(1).uppercased() + cut.dropFirst()

        return AnalyzedFood(
            label: label,
            triggers: found,
            note: found.isEmpty ? "No obvious dietary triggers spotted." : "Estimated locally from your description.")
    }
}
