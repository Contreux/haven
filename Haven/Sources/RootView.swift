import SwiftUI
import HavenDesignSystem
import HavenCore

struct RootView: View {
    @State private var service = ConvexService()
    @State private var store: TodayStore?
    @State private var onboarded: Bool?

    var body: some View {
        Group {
            if let isOnboarded = onboarded {
                if isOnboarded, let store {
                    RootTabView(store: store)
                } else {
                    OnboardingFlow(service: service, onFinished: { onboarded = true })
                }
            } else {
                ProgressView()   // brief settings check
            }
        }
        .task {
            let s = try? await service.getSettings()
            onboarded = s?.onboarded ?? false
            store = TodayStore(source: service, today: Self.todayString())
        }
    }

    static func todayString() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
