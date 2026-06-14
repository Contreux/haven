import SwiftUI
import HavenDesignSystem

struct TopBar: View {
    @Environment(\.theme) private var theme
    let dateText: String
    let streak: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Today").havenText(.screenTitle, color: theme.ink)
                Text(dateText).havenText(.meta, color: theme.inkSoft)
            }
            Spacer()
            if streak > 0 {
                HStack(spacing: Spacing.s2) {
                    Image(systemName: "flame.fill").foregroundStyle(theme.accent)
                    Text("\(streak)").havenText(.meta, color: theme.accent)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s2)
                .background(theme.streakBg, in: Capsule())
            }
        }
    }
}
