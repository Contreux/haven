import SwiftUI
import HavenDesignSystem

struct SheetHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            RoundedRectangle(cornerRadius: Radius.pill)
                .fill(theme.hairline).frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.s2)
            Text(title).havenText(.sectionHead, color: theme.ink)
            Text(subtitle).havenText(.meta, color: theme.inkSoft)
        }
    }
}
