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
            HStack(spacing: Spacing.s2) {
                if streak > 0 {
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: "drop.fill").foregroundStyle(theme.accent)
                        Text("\(streak)").havenText(.meta, color: theme.accent)
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s2)
                    .background(theme.streakBg, in: Capsule())
                }
                iconButton("magnifyingglass")
                iconButton("person")
            }
        }
    }

    // Visual chrome — search + profile. Actions land in later milestones (M5 profile).
    private func iconButton(_ name: String) -> some View {
        Button { } label: {
            Image(systemName: name)
                .foregroundStyle(theme.inkSoft)
                .frame(width: 38, height: 38)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        }
    }
}
