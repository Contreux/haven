import SwiftUI
import HavenDesignSystem
import HavenCore

struct OnboardingFlow: View {
    @Environment(\.theme) private var theme
    let service: ConvexService
    let onFinished: () -> Void

    enum Step: Equatable { case welcome, question(Int), synthesis, permWeather, permReminders, paywall, done }
    @State private var step: Step = .welcome
    @State private var forward = true   // drives slide direction
    @State private var storeKit = StoreService()
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
        ZStack {
            theme.bg.ignoresSafeArea()
            currentScreen
                .id(transitionKey)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal:   .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
        }
    }

    @ViewBuilder private var currentScreen: some View {
        switch step {
        case .welcome:
            WelcomeScreen(onStart: { go(.question(0)) }, onSignIn: { go(.question(0)) })
        case .question(let i):
            let q = visibleQuestions[i]
            QuestionScreen(q: q, index: i, total: visibleQuestions.count,
                selected: bindingFor(q.id),
                onBack: { i == 0 ? back(.welcome) : back(.question(i - 1)) },
                onNext: { i + 1 < visibleQuestions.count ? go(.question(i + 1)) : go(.synthesis) })
        case .synthesis:
            SynthesisScreen(profile: buildProfile(answers), onNext: { go(.permWeather) })
        case .permWeather:
            PermWeatherScreen(onEnable: { Task { if let c = await loc.request() { lat = c.latitude; lon = c.longitude }; go(.permReminders) } },
                              onSkip: { go(.permReminders) },
                              onBack: { back(.synthesis) })
        case .permReminders:
            // v1 ships free: skip the paywall and finish onboarding directly.
            // The `.paywall` case below is retained for v1.1 when subscriptions go live.
            PermRemindersScreen(time: $reminderTime,
                onEnable: { Task { _ = await Reminders.enable(); Reminders.schedule(hour: 18, minute: 0); await finish(subscribed: false) } },
                onSkip: { Task { await finish(subscribed: false) } },
                onBack: { back(.permWeather) })
        case .paywall:
            PaywallScreen(store: storeKit,
                onSubscribe: { id in Task { await subscribe(id) } },
                onRestore: { Task { await restore() } },
                onClose: { Task { await finish(subscribed: false) } })
        case .done:
            DoneScreen(onEnter: onFinished)
        }
    }

    /// Advance to a later step (slide in from the right).
    private func go(_ s: Step) { forward = true; withAnimation(.easeInOut(duration: 0.35)) { step = s } }
    /// Return to an earlier step (slide in from the left).
    private func back(_ s: Step) { forward = false; withAnimation(.easeInOut(duration: 0.35)) { step = s } }

    private var transitionKey: String {
        switch step {
        case .welcome: "welcome"
        case .question(let i): "q\(i)"
        case .synthesis: "synthesis"
        case .permWeather: "permWeather"
        case .permReminders: "permReminders"
        case .paywall: "paywall"
        case .done: "done"
        }
    }

    private func bindingFor(_ id: String) -> Binding<[String]> {
        Binding(get: { answers[id] ?? [] }, set: { answers[id] = $0 })
    }

    private func subscribe(_ id: String) async {
        if let tx = await storeKit.purchase(id) { try? await service.validateSubscription(transactionId: tx) }
        await finish(subscribed: true)
    }

    /// Restore Purchases (App Store requirement): if a prior subscription is active, record it and proceed.
    private func restore() async {
        if await storeKit.hasEntitlement() { try? await service.setSubscribed(true) }
        await finish(subscribed: true)
    }

    private func finish(subscribed: Bool) async {
        try? await service.completeOnboarding(answersJSON: answersJSON(from: answers), reminderTime: reminderTime, lat: lat, lon: lon)
        go(.done)
    }
}
