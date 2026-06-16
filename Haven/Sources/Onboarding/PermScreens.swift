import SwiftUI
import HavenDesignSystem

struct PermWeatherScreen: View {
    let onEnable: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    var body: some View {
        PermScaffold(
            icon: "cloud",
            title: "Let Haven watch the weather for you",
            bodyMarkdown: "A fast drop in **barometric pressure** is one of the most common migraine triggers. With your location, Haven warns you on high-risk days — before the attack.",
            ctaIcon: "mappin.and.ellipse", cta: "Enable location", ctaId: "ob-loc-enable",
            skip: "Not now", onCta: onEnable, onSkip: onSkip, onBack: onBack
        ) { EmptyView() }
    }
}

struct PermRemindersScreen: View {
    @Environment(\.theme) private var theme
    @Binding var time: String
    let onEnable: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    private let times = [("morning", "Morning", "8:00 AM"), ("midday", "Midday", "12:30 PM"),
                         ("evening", "Evening", "6:00 PM"), ("night", "Before bed", "9:30 PM")]
    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        PermScaffold(
            icon: "bell",
            title: "One gentle nudge a day",
            bodyMarkdown: "Consistent logging is what makes the patterns show up. We'll send **one** quiet reminder — no spam. When suits you?",
            ctaIcon: nil, cta: "Turn on reminders", ctaId: "ob-rem-enable",
            skip: "Maybe later", onCta: onEnable, onSkip: onSkip, onBack: onBack
        ) {
            LazyVGrid(columns: cols, spacing: Spacing.s3) {
                ForEach(times, id: \.0) { v, label, t in
                    let on = time == v
                    Button { time = v } label: {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text(label).havenText(.sectionHead, color: on ? theme.bg : theme.ink)
                            Text(t).havenText(.meta, color: on ? theme.accent : theme.inkSoft)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.s5)
                        .background(on ? theme.ink : theme.chip, in: RoundedRectangle(cornerRadius: Radius.lg))
                    }
                }
            }
        }
    }
}

/// Shared layout for the permission screens: progress header, centered icon tile + glow,
/// centered serif title and body, optional extra content, then CTA + skip — matching `.ob-perm`.
private struct PermScaffold<Extra: View>: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let bodyMarkdown: String
    let ctaIcon: String?
    let cta: String
    let ctaId: String
    let skip: String
    let onCta: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.s5) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                        .frame(width: 34, height: 34).background(theme.chip, in: RoundedRectangle(cornerRadius: 11))
                }
                Capsule().fill(theme.accent).frame(height: 4).frame(maxWidth: .infinity)
                Color.clear.frame(width: 38, height: 1)
            }
            .padding(.horizontal, Spacing.s7).padding(.top, Spacing.s4)

            VStack(spacing: 0) {
                Spacer(minLength: Spacing.s8)
                ZStack {
                    // frame must be ≥ 2×endRadius, else the still-opaque gradient is clipped into a square.
                    RadialGradient(colors: [theme.accent.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 95)
                        .frame(width: 190, height: 190)
                    RoundedRectangle(cornerRadius: 28).fill(theme.surface).frame(width: 96, height: 96)
                        .overlay(Image(systemName: icon).font(.system(size: 40)).foregroundStyle(theme.accent))
                }
                Text(title).havenText(.cardTitle, color: theme.ink)
                    .multilineTextAlignment(.center).padding(.top, Spacing.s7)
                styledBody.multilineTextAlignment(.center).frame(maxWidth: 320).padding(.top, Spacing.s5)
                extra().padding(.top, Spacing.s8)
                Spacer(minLength: Spacing.s8)
            }
            .padding(.horizontal, Spacing.s7)

            VStack(spacing: Spacing.s4) {
                Button(action: onCta) {
                    HStack(spacing: Spacing.s3) {
                        if let ctaIcon { Image(systemName: ctaIcon).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ctaInk) }
                        Text(cta).havenText(.sectionHead, color: theme.ctaInk)
                    }
                    .primaryCTA()
                }
                .accessibilityIdentifier(ctaId)
                Button(action: onSkip) { Text(skip).havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity) }
            }
            .padding(.horizontal, Spacing.s7).padding(.bottom, Spacing.s7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }

    // Body copy with **bold** runs rendered in the brighter ink color, per the design.
    private var styledBody: Text {
        var a = (try? AttributedString(markdown: bodyMarkdown)) ?? AttributedString(bodyMarkdown)
        a.font = .custom(FontFamily.sans.fontName(weight: .regular), size: TypeScale.base)
        a.foregroundColor = theme.inkSoft
        let strong = a.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }.map(\.range)
        for r in strong {
            a[r].font = .custom(FontFamily.sans.fontName(weight: .semibold), size: TypeScale.base).weight(.semibold)
            a[r].foregroundColor = theme.ink
        }
        return Text(a)
    }
}
