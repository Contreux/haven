import SwiftUI
import HavenDesignSystem

struct TopBar: View {
    @Environment(\.theme) private var theme
    let dateText: String
    let streak: Int
    var onProfile: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Today").havenText(.screenTitle, color: theme.ink)
                Text(dateText).havenText(.meta, color: theme.inkSoft)
            }
            Spacer()
            HStack(spacing: Spacing.s2) {
                if streak > 0 {
                    // Flame + bold count on a streak-tinted rounded rect, sized to the icon buttons.
                    // Asymmetric padding (11 / 13) balances the flame's optical weight, per the design.
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill").font(.system(size: 15)).foregroundStyle(theme.accent)
                        Text("\(streak)").havenText(.sectionHead, color: theme.accent).fontWeight(.bold)
                    }
                    .padding(.leading, 11).padding(.trailing, 13)
                    .frame(height: 38)
                    .background(theme.streakBg, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .accessibilityIdentifier("streak")
                }
                iconButton("magnifyingglass")
                iconButton("person", action: onProfile, id: "open-profile")
            }
        }
    }

    private func iconButton(_ name: String, action: @escaping () -> Void = {}, id: String? = nil) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .foregroundStyle(theme.inkSoft)
                .frame(width: 38, height: 38)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        }
        .accessibilityIdentifier(id ?? name)
    }
}
