import Foundation

/// Consecutive days with an entry, counting back from `asOf` (a "YYYY-MM-DD").
public func streak(loggedDates: [String], asOf today: String) -> Int {
    let set = Set(loggedDates)
    let fmt = DateFormatter()
    fmt.calendar = Calendar(identifier: .gregorian)
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.dateFormat = "yyyy-MM-dd"
    guard var cursor = fmt.date(from: today) else { return 0 }

    var count = 0
    while set.contains(fmt.string(from: cursor)) {
        count += 1
        cursor = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: cursor)!
    }
    return count
}
