import SwiftUI
import HavenDesignSystem
import HavenCore

struct OnboardingFlow: View {
    @Environment(\.theme) private var theme
    let service: ConvexService
    let onFinished: () -> Void

    enum Step: Equatable { case welcome, question(Int), synthesis, permWeather, permReminders, done }
    @State private var step: Step = .welcome
    @State private var answers: [String: [String]] = [:]
    @State private var reminderTime = "evening"
    @State private var lat: Double?; @State private var lon: Double?
    @State private var loc = LocationOnce()

    private var visibleQuestions: [OnboardingQuestion] {
        OnboardingCatalog.questions.filter { q in
            guard let req = q.requiresSex else { return true }
            return req.contains(answers["sex"]?.first ?? "")
        }
    }

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeScreen(onStart: { step = .question(0) }, onSignIn: { step = .question(0) })
            case .question(let i):
                let q = visibleQuestions[i]
                QuestionScreen(q: q, index: i, total: visibleQuestions.count,
                    selected: bindingFor(q.id),
                    onBack: { i == 0 ? (step = .welcome) : (step = .question(i - 1)) },
                    onNext: { i + 1 < visibleQuestions.count ? (step = .question(i + 1)) : (step = .synthesis) })
                .id(q.id)
            case .synthesis:
                SynthesisScreen(profile: buildProfile(answers), onNext: { step = .permWeather })
            case .permWeather:
                PermWeatherScreen(onEnable: { Task { if let c = await loc.request() { lat = c.latitude; lon = c.longitude }; step = .permReminders } },
                                  onSkip: { step = .permReminders })
            case .permReminders:
                PermRemindersScreen(time: $reminderTime,
                    onEnable: { Task { _ = await Reminders.enable(); Reminders.schedule(hour: 18, minute: 0); await finish() } },
                    onSkip: { Task { await finish() } })
            case .done:
                DoneScreen(onEnter: onFinished)
            }
        }
    }

    private func bindingFor(_ id: String) -> Binding<[String]> {
        Binding(get: { answers[id] ?? [] }, set: { answers[id] = $0 })
    }

    private func finish() async {
        let json = (try? JSONSerialization.data(withJSONObject: answers)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        try? await service.completeOnboarding(answersJSON: json, reminderTime: reminderTime, lat: lat, lon: lon)
        step = .done
    }
}
