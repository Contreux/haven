import SwiftUI
import HavenDesignSystem

/// Token-styled segmented control over string options.
struct Segmented: View {
    @Environment(\.theme) private var theme
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { opt in
                Button { selection = opt } label: {
                    Text(opt)
                        .havenText(.meta, color: selection == opt ? theme.ctaInk : theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.s3)
                        .background(selection == opt ? theme.ctaBg : Color.clear,
                                    in: RoundedRectangle(cornerRadius: Radius.sm))
                }
            }
        }
        .padding(Spacing.s1)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    }
}
