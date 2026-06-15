import SwiftUI
import HavenCore

@MainActor @Observable
final class ProfileStore {
    private let source: DayDataSource
    private(set) var answers: [String: [String]] = [:]
    private(set) var settings: Settings = Settings(theme: "dark")
    var days: [DayLog] = []

    init(source: DayDataSource) { self.source = source }

    var profile: Profile { buildProfile(answers) }
    var rows: [ProfileRow] { profileRows(answers: answers) }

    func load() async {
        if let s = try? await source.getSettings() {
            settings = s
            answers = answersDict(from: s.answers)
        }
        source.observeDays { [weak self] in self?.days = $0 }
    }

    func saveAnswer(questionId: String, values: [String]) async {
        answers[questionId] = values
        try? await source.updateAnswers(answersJSON(from: answers))
    }

    func setReminderTime(_ time: String) async {
        settings = Settings(theme: settings.theme, onboarded: settings.onboarded, subscribed: settings.subscribed,
                            answers: settings.answers, reminderTime: time, lat: settings.lat, lon: settings.lon)
        try? await source.setReminderTime(time)
    }

    func deleteData() async { try? await source.deleteMyData() }
}
