import Foundation

public struct TriggerStat: Sendable, Equatable, Identifiable {
    public let name: String
    public let level: Level
    public let total: Int
    public let onMigraine: Int
    public var id: String { name }
}

public struct InsightsResult: Sendable, Equatable {
    public let migraineDays: Int
    public let trackedDays: Int
    public let triggersSeen: Int
    public let ranked: [TriggerStat]
}

public enum Insights {
    public static func compute(_ days: [DayLog]) -> InsightsResult {
        var migraineDays = 0
        var trackedDays = 0
        // name -> (level, total, onMigraine)
        var acc: [String: (level: Level, total: Int, onMig: Int)] = [:]

        for day in days {
            let hadMigraine = day.migraine?.had ?? false
            if hadMigraine { migraineDays += 1 }
            if !day.foods.isEmpty || day.factors != nil || !day.symptoms.isEmpty { trackedDays += 1 }
            for food in day.foods {
                for t in food.triggers {
                    var entry = acc[t.label] ?? (level: t.level, total: 0, onMig: 0)
                    entry.total += 1
                    if hadMigraine { entry.onMig += 1 }
                    acc[t.label] = entry
                }
            }
        }

        let ranked = acc.map { TriggerStat(name: $0.key, level: $0.value.level, total: $0.value.total, onMigraine: $0.value.onMig) }
            .sorted { a, b in a.onMigraine != b.onMigraine ? a.onMigraine > b.onMigraine : a.total > b.total }

        return InsightsResult(migraineDays: migraineDays, trackedDays: trackedDays,
                              triggersSeen: acc.count, ranked: ranked)
    }
}
