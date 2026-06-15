import SwiftUI
import HavenDesignSystem
import HavenCore

struct SynthesisScreen: View {
    @Environment(\.theme) private var theme
    let profile: Profile
    let onNext: () -> Void
    @State private var revealed = false
    @State private var line = 0
    private let lines = ["Mapping what you've told us…", "Checking your weather sensitivity…", "Lining up suspected triggers…", "Setting your tracking baseline…"]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            if revealed { reveal } else { loading }
        }
        .task {
            for i in 0..<5 { try? await Task.sleep(nanoseconds: 600_000_000); line = i % lines.count }
            revealed = true
        }
    }

    private var loading: some View {
        VStack(spacing: Spacing.s4) {
            ProgressView()
            Text("Building your profile").havenText(.sectionHead, color: theme.ink)
            Text(lines[line]).havenText(.meta, color: theme.inkSoft)
        }.padding(Spacing.s7)
    }

    private var reveal: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            Text("Your starting point".uppercased()).havenText(.eyebrow, color: theme.accent)
            Text("Here's what we'll build on.").havenText(.screenTitle, color: theme.ink)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("YOUR PROFILE").havenText(.eyebrow, color: theme.inkFaint)
                Text(profile.klass).havenText(.sectionHead, color: theme.ink)
                FlowChips(items: ["Suspected:"] + profile.suspected)
                Divider().overlay(theme.hairline)
                Text("WHAT HAVEN WILL WATCH").havenText(.eyebrow, color: theme.inkFaint)
                ForEach(profile.watch, id: \.title) { w in
                    HStack(alignment: .top, spacing: Spacing.s3) {
                        Image(systemName: "checkmark.circle").foregroundStyle(theme.accent)
                        VStack(alignment: .leading) {
                            Text(w.title).havenText(.body, color: theme.ink)
                            Text(w.sub).havenText(.meta, color: theme.inkSoft)
                        }
                    }
                }
            }
            .padding(Spacing.s5).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
            Spacer()
            Button(action: onNext) {
                Text("Looks right").havenText(.sectionHead, color: theme.ctaInk)
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                    .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            }.accessibilityIdentifier("ob-synth-next")
        }.padding(Spacing.s7)
    }
}
