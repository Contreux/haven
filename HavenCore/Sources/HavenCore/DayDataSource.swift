import Foundation

@MainActor
public protocol DayDataSource: AnyObject {
    /// Subscribe to a day's reactive updates. `onChange` fires with the current value
    /// immediately and again whenever the backend pushes a change.
    func observeDay(date: String, onChange: @escaping (DayLog?) -> Void)
    /// Subscribe to all of the device's day docs (ascending by date), reactively.
    func observeDays(onChange: @escaping ([DayLog]) -> Void)
    /// The M1 write path. Upserts the day's factors.
    func setFactors(date: String, factors: Factors, loggedAt: String) async throws
    func setMigraine(date: String, migraine: Migraine) async throws
    func removeMigraine(date: String) async throws
    func setSymptoms(date: String, symptoms: [String], loggedAt: String) async throws
    func addFood(date: String, food: FoodEntry) async throws
    func removeFood(date: String, foodIndex: Int) async throws
    func analyzeFood(description: String) async throws -> AnalyzedFood
    func fetchWeather(lat: Double, lon: Double) async throws -> Weather
    func completeOnboarding(answersJSON: String, reminderTime: String?, lat: Double?, lon: Double?) async throws
    func getSettings() async throws -> Settings
    func setSubscribed(_ subscribed: Bool) async throws
}
