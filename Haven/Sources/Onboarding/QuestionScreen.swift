import SwiftUI
import HavenDesignSystem
import HavenCore

struct QuestionScreen: View {
    @Environment(\.theme) private var theme
    let q: OnboardingQuestion
    let index: Int; let total: Int
    @Binding var selected: [String]
    let onBack: () -> Void
    let onNext: () -> Void

    private var canNext: Bool { !selected.isEmpty }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                HStack(spacing: Spacing.s3) {
                    Button(action: onBack) { Image(systemName: "chevron.left").foregroundStyle(theme.inkSoft) }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.track)
                            Capsule().fill(theme.accent).frame(width: geo.size.width * CGFloat(index + 1) / CGFloat(total))
                        }
                    }.frame(height: Spacing.s1)
                }
                Text(q.kicker.uppercased()).havenText(.eyebrow, color: theme.accent)
                Text(q.title).havenText(.screenTitle, color: theme.ink)
                if let sub = q.sub { Text(sub).havenText(.body, color: theme.inkSoft) }
                ScrollView {
                    if q.layout == .grid { grid } else { list }
                }
                Button(action: onNext) {
                    Text("Next").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(canNext ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
                }.disabled(!canNext).accessibilityIdentifier("ob-next")
            }.padding(Spacing.s7)
        }
    }

    private func toggle(_ v: String) {
        if q.kind == .single { selected = [v] }
        else if selected.contains(v) { selected.removeAll { $0 == v } }
        else { selected.append(v) }
    }

    private var list: some View {
        VStack(spacing: Spacing.s3) {
            ForEach(allOptions) { opt in
                let on = selected.contains(opt.value)
                Button { toggle(opt.value) } label: {
                    HStack {
                        Text(opt.label).havenText(.body, color: on ? theme.ctaInk : theme.ink)
                        Spacer()
                        if on { Image(systemName: "checkmark").foregroundStyle(theme.ctaInk) }
                    }
                    .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
                    .background(on ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                }
            }
        }
    }
    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s3) {
            ForEach(allOptions) { opt in
                let on = selected.contains(opt.value)
                Button { toggle(opt.value) } label: {
                    VStack(spacing: Spacing.s2) {
                        if let icon = opt.icon { Image(systemName: icon) }
                        Text(opt.label).havenText(.meta, color: on ? theme.ctaInk : theme.ink).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).frame(height: 88)
                    .background(on ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    .foregroundStyle(on ? theme.ctaInk : theme.inkSoft)
                }
            }
        }
    }
    private var allOptions: [OnboardingOption] { q.notSure.map { q.options + [$0] } ?? q.options }
}
