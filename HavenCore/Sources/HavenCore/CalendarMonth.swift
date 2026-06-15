import Foundation

public enum DayMark: Sendable, Equatable { case none, food, symptoms }

public struct CalendarCell: Sendable, Equatable, Identifiable {
    public let id: Int          // unique within the month (blanks use negative ids)
    public let day: Int?        // nil = leading blank
    public let date: String?    // "YYYY-MM-DD"
    public let migraineSeverity: String?
    public let mark: DayMark
    public let isToday: Bool
}

public struct CalendarMonth: Sendable, Equatable {
    public let year: Int
    public let month: Int       // 1-12
    public let cells: [CalendarCell]

    public static func build(days: [DayLog], year: Int, month: Int, today: String) -> CalendarMonth {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let fmt = DateFormatter()
        fmt.calendar = cal; fmt.timeZone = cal.timeZone
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"

        let byDate = Dictionary(days.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })

        let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let weekday = cal.component(.weekday, from: firstOfMonth) // 1 = Sunday
        let leadingBlanks = weekday - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count

        var cells: [CalendarCell] = []
        for i in 0..<leadingBlanks {
            cells.append(CalendarCell(id: -(i + 1), day: nil, date: nil, migraineSeverity: nil, mark: .none, isToday: false))
        }
        for d in 1...daysInMonth {
            let date = cal.date(from: DateComponents(year: year, month: month, day: d))!
            let key = fmt.string(from: date)
            let log = byDate[key]
            // Normalize casing so consumers get "Mild"/"Moderate"/"Severe" regardless of how it was stored.
            let severity = (log?.migraine?.had ?? false) ? log?.migraine?.severity.capitalized : nil
            let mark: DayMark = !(log?.foods.isEmpty ?? true) ? .food
                : !(log?.symptoms.isEmpty ?? true) ? .symptoms : .none
            cells.append(CalendarCell(id: d, day: d, date: key, migraineSeverity: severity, mark: mark, isToday: key == today))
        }
        return CalendarMonth(year: year, month: month, cells: cells)
    }
}
