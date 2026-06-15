import Foundation

public enum DishVerdict: String, Codable, Sendable, Equatable {
    case safe, caution, avoid
    public init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self))?.lowercased() ?? ""
        self = DishVerdict(rawValue: raw) ?? .caution   // unknown -> caution
    }
}

public struct MenuDish: Codable, Sendable, Equatable, Identifiable {
    public let name: String
    public let verdict: DishVerdict
    public let triggers: [String]
    public let reason: String
    public var id: String { name }

    public init(name: String, verdict: DishVerdict, triggers: [String] = [], reason: String = "") {
        self.name = name; self.verdict = verdict; self.triggers = triggers; self.reason = reason
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        verdict = (try? c.decode(DishVerdict.self, forKey: .verdict)) ?? .caution
        triggers = (try? c.decode([String].self, forKey: .triggers)) ?? []
        reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
    }

    /// Maps the dish to trigger chips for logging. Verdict drives the level; safe dishes carry no chips.
    public func asTriggerChips() -> [TriggerChip] {
        let level: Level
        switch verdict {
        case .avoid: level = .high
        case .caution: level = .mid
        case .safe: return []
        }
        return triggers.map { TriggerChip(label: $0, level: level, reason: reason.isEmpty ? nil : reason) }
    }
}

public struct MenuScan: Codable, Sendable, Equatable {
    public let dishes: [MenuDish]
    public init(dishes: [MenuDish]) { self.dishes = dishes }

    public enum Lead: Sendable, Equatable { case canEat, cantEat }

    /// canEat = safe + caution; cantEat = avoid. Lead with the SHORTER list (more actionable); tie -> canEat.
    public func grouped() -> (canEat: [MenuDish], cantEat: [MenuDish], lead: Lead) {
        let canEat = dishes.filter { $0.verdict != .avoid }
        let cantEat = dishes.filter { $0.verdict == .avoid }
        let lead: Lead = cantEat.count < canEat.count ? .cantEat : .canEat
        return (canEat, cantEat, lead)
    }
}
