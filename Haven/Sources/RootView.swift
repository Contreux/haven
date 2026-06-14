import SwiftUI
import HavenDesignSystem
import HavenCore

struct RootView: View {
    @State private var store: TodayStore = {
        let service = ConvexService()
        return TodayStore(source: service, today: Self.todayString())
    }()

    var body: some View {
        TodayScreen(store: store)
    }

    static func todayString() -> String {
        // POSIX locale + Gregorian so the Convex date key is stable regardless of device locale.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
