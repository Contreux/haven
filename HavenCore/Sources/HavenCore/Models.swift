import Foundation

public enum Level: String, Codable, Sendable, Equatable {
    case low, mid, high
}

public struct TriggerChip: Codable, Sendable, Equatable, Identifiable {
    public let label: String
    public let level: Level
    // Composite so two same-label triggers (different level) don't collide in ForEach.
    public var id: String { "\(label)-\(level.rawValue)" }
}

public struct FoodEntry: Codable, Sendable, Equatable {
    public let name: String
    public let time: String          // "HH:mm"
    public let triggers: [TriggerChip]
}

public struct Factors: Codable, Sendable, Equatable {
    public let sleepHours: Double
    public let stress: Level
    public let hydration: Level
    public let weatherSensitive: Bool

    public init(sleepHours: Double, stress: Level, hydration: Level, weatherSensitive: Bool) {
        self.sleepHours = sleepHours; self.stress = stress
        self.hydration = hydration; self.weatherSensitive = weatherSensitive
    }
}

public struct Migraine: Codable, Sendable, Equatable {
    public let had: Bool
    public let severity: String
    public let time: String          // "HH:mm"
    public let notes: String
}

public struct DayLog: Codable, Sendable, Equatable {
    public let userId: String
    public let date: String          // "YYYY-MM-DD"
    public let factors: Factors?
    public let factorsLoggedAt: String?
    public let migraine: Migraine?
    public let symptoms: [String]
    public let symptomsLoggedAt: String?
    public let foods: [FoodEntry]
}

public struct Settings: Codable, Sendable, Equatable {
    public let theme: String
}
