import Foundation

public enum LedgerKind: Sendable, Equatable { case factors, food, symptoms, migraine }

public struct LedgerEntry: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: LedgerKind
    public let time: String          // "HH:mm" — sort key
    public let title: String
    public let subtitle: String
    public let triggers: [TriggerChip]   // food only; [] otherwise
}

/// Pure §6.5 mapping: merge a day's sub-records into one time-sorted ledger.
/// Weather is never included — it is external context, never logged.
public func buildLedger(from day: DayLog) -> [LedgerEntry] {
    var entries: [LedgerEntry] = []

    if let f = day.factors, let at = day.factorsLoggedAt {
        let sleep = f.sleepHours.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0fh", f.sleepHours) : String(format: "%.1fh", f.sleepHours)
        entries.append(LedgerEntry(
            id: "factors-\(day.date)", kind: .factors, time: at,
            title: "Daily factors",
            subtitle: "Sleep \(sleep) · Stress \(f.stress.rawValue) · Water \(f.hydration.rawValue)",
            triggers: []))
    }

    for (i, food) in day.foods.enumerated() {
        entries.append(LedgerEntry(
            id: "food-\(day.date)-\(i)", kind: .food, time: food.time,
            title: food.name,
            subtitle: food.triggers.isEmpty ? "No known triggers" : "\(food.triggers.count) trigger(s)",
            triggers: food.triggers))
    }

    if !day.symptoms.isEmpty, let at = day.symptomsLoggedAt {
        entries.append(LedgerEntry(
            id: "symptoms-\(day.date)", kind: .symptoms, time: at,
            title: "Symptoms",
            subtitle: day.symptoms.joined(separator: " · "),
            triggers: []))
    }

    if let m = day.migraine, m.had {
        let notes = m.notes.isEmpty ? "" : " · \(m.notes)"
        entries.append(LedgerEntry(
            id: "migraine-\(day.date)", kind: .migraine, time: m.time,
            title: "Migraine",
            subtitle: "\(m.severity.capitalized)\(notes)",
            triggers: []))
    }

    return entries.sorted { $0.time < $1.time }
}
