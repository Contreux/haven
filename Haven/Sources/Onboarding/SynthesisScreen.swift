import SwiftUI
import HavenDesignSystem
import HavenCore

struct SynthesisScreen: View {
    @Environment(\.theme) private var theme
    let profile: Profile
    let onNext: () -> Void

    @State private var revealed = false
    @State private var line = 0
    @State private var barProgress: CGFloat = 0
    private let lines = [
        "Mapping what you've told us…",
        "Checking your weather sensitivity…",
        "Lining up suspected triggers…",
        "Setting your tracking baseline…",
    ]

    // Inline text fonts built from public design tokens (two-tone runs aren't expressible via havenText).
    private var watchTitleFont: Font { Font.custom(FontFamily.sans.fontName(weight: .semibold), size: TypeScale.base).weight(.semibold) }
    private var watchSubFont: Font { Font.custom(FontFamily.sans.fontName(weight: .regular), size: TypeScale.base) }
    private var chipFont: Font { Font.custom(FontFamily.sans.fontName(weight: .semibold), size: TypeScale.base).weight(.semibold) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            if revealed { reveal } else { loading }
        }
        .task {
            barProgress = 0
            withAnimation(.easeInOut(duration: 2.4)) { barProgress = 1 }
            let start = Date()
            while Date().timeIntervalSince(start) < 2.5 {
                try? await Task.sleep(nanoseconds: 600_000_000)
                line = (line + 1) % lines.count
            }
            withAnimation(.easeOut(duration: 0.3)) { revealed = true }
        }
    }

    // MARK: - Loading

    private var loading: some View {
        ZStack {
            // Soft accent glow behind the orb.
            RadialGradient(colors: [theme.accent.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 160)
                .frame(width: 320, height: 320)
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(theme.surface)
                        .overlay(Circle().stroke(theme.hairline, lineWidth: 2))
                        .frame(width: 76, height: 76)
                    ProgressView().tint(theme.accent)
                }
                .padding(.bottom, Spacing.s8)
                Text("Building your profile").havenText(.screenTitle, color: theme.ink)
                Text(lines[line]).havenText(.body, color: theme.inkSoft)
                    .padding(.top, Spacing.s5)
                    .animation(.easeInOut(duration: 0.3), value: line)
                progressBar.padding(.top, Spacing.s8)
            }
        }
        .padding(.horizontal, Spacing.s10)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(theme.track).frame(width: 170, height: 4)
            Capsule().fill(theme.accent).frame(width: 170 * barProgress, height: 4)
        }
    }

    // MARK: - Reveal

    private var reveal: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your starting point").havenText(.eyebrow, color: theme.accent)
                    Text("Here's what we'll build on.").havenText(.screenTitle, color: theme.ink)
                        .padding(.top, Spacing.s3)
                    Text("Based on your answers — you can adjust any of this later.")
                        .havenText(.body, color: theme.inkSoft)
                        .padding(.top, Spacing.s4)

                    card.padding(.top, Spacing.s8)
                }
                .padding(.horizontal, Spacing.s7)
                .padding(.top, Spacing.s7)
            }
            Button(action: onNext) {
                HStack(spacing: Spacing.s2) {
                    Text("Looks right").havenText(.sectionHead, color: theme.ctaInk)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ctaInk)
                }
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            }
            .accessibilityIdentifier("ob-synth-next")
            .padding(.horizontal, Spacing.s7)
            .padding(.vertical, Spacing.s6)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your profile").havenText(.eyebrow, color: theme.inkSoft)
            Text(profile.klass).havenText(.cardTitle, color: theme.ink)
                .padding(.top, Spacing.s2)

            FlowLayout(spacing: Spacing.s2) {
                chip("Suspected:", accent: true)
                ForEach(profile.suspected, id: \.self) { chip($0, accent: false) }
            }
            .padding(.top, Spacing.s5)

            Rectangle().fill(theme.hairline).frame(height: 1).padding(.vertical, Spacing.s7)

            Text("What Haven will watch for you").havenText(.eyebrow, color: theme.inkSoft)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                ForEach(profile.watch, id: \.title) { watchRow($0) }
            }
            .padding(.top, Spacing.s5)
        }
        .padding(Spacing.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xxl))
    }

    private func chip(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(chipFont)
            .foregroundStyle(accent ? theme.accent : theme.ink)
            .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s2)
            .background(accent ? theme.accent.opacity(0.14) : theme.chip, in: Capsule())
    }

    private func watchRow(_ w: Profile.Watch) -> some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.xs).fill(theme.accent.opacity(0.14)).frame(width: 24, height: 24)
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(theme.accent)
            }
            (Text(w.title).font(watchTitleFont).foregroundColor(theme.ink)
                + Text("  —  \(w.sub)").font(watchSubFont).foregroundColor(theme.inkSoft))
                .lineSpacing(TypeScale.base * (Leading.snug - 1))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }
}

/// Minimal wrapping layout for the suspected-trigger chips (flex-wrap parity).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > maxWidth, x > 0 {
                y += rowHeight + spacing; x = 0; rowHeight = 0
            }
            x += sz.width + spacing
            rowHeight = max(rowHeight, sz.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowHeight = max(rowHeight, sz.height)
        }
    }
}
