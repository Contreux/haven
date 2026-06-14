import Foundation

@MainActor
public protocol DayDataSource: AnyObject {
    /// Subscribe to a day's reactive updates. `onChange` fires with the current value
    /// immediately and again whenever the backend pushes a change.
    func observeDay(date: String, onChange: @escaping (DayLog?) -> Void)
    /// The M1 write path. Upserts the day's factors.
    func setFactors(date: String, factors: Factors, loggedAt: String) async throws
}
