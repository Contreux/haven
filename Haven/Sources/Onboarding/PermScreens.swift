import SwiftUI
import HavenDesignSystem

struct PermWeatherScreen: View {
    @Environment(\.theme) private var theme
    let onEnable: () -> Void; let onSkip: () -> Void
    var body: some View { PermBodyView(icon: "cloud", title: "Let Haven watch the weather for you",
        bodyText: "A fast drop in barometric pressure is one of the most common migraine triggers. With your location, Haven warns you on high-risk days — before the attack.",
        cta: "Enable location", onCta: onEnable, onSkip: onSkip, ctaId: "ob-loc-enable") }
}

struct PermRemindersScreen: View {
    @Environment(\.theme) private var theme
    @Binding var time: String
    let onEnable: () -> Void; let onSkip: () -> Void
    private let times = [("morning","Morning","8:00 AM"),("midday","Midday","12:30 PM"),("evening","Evening","6:00 PM"),("night","Before bed","9:30 PM")]
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Spacer()
                Image(systemName: "bell").imageScale(.large).foregroundStyle(theme.accent)
                Text("One gentle nudge a day").havenText(.screenTitle, color: theme.ink)
                Text("Consistent logging is what makes the patterns show up. We'll send one quiet reminder. When suits you?").havenText(.body, color: theme.inkSoft)
                ForEach(times, id: \.0) { v, label, t in
                    let on = time == v
                    Button { time = v } label: {
                        HStack { Text(label).havenText(.body, color: on ? theme.ctaInk : theme.ink); Spacer(); Text(t).havenText(.meta, color: on ? theme.ctaInk : theme.inkSoft) }
                            .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
                            .background(on ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
                Spacer()
                Button(action: onEnable) { Text("Turn on reminders").havenText(.sectionHead, color: theme.ctaInk).frame(maxWidth: .infinity).padding(.vertical, Spacing.s5).background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg)) }.accessibilityIdentifier("ob-rem-enable")
                Button(action: onSkip) { Text("Maybe later").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity) }
            }.padding(Spacing.s7)
        }
    }
}

private struct PermBodyView: View {
    @Environment(\.theme) private var theme
    let icon: String; let title: String; let bodyText: String; let cta: String
    let onCta: () -> Void; let onSkip: () -> Void; let ctaId: String
    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Spacer()
                Image(systemName: icon).imageScale(.large).foregroundStyle(theme.accent)
                Text(title).havenText(.screenTitle, color: theme.ink)
                Text(bodyText).havenText(.body, color: theme.inkSoft)
                Spacer()
                Button(action: onCta) { Text(cta).havenText(.sectionHead, color: theme.ctaInk).frame(maxWidth: .infinity).padding(.vertical, Spacing.s5).background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg)) }.accessibilityIdentifier(ctaId)
                Button(action: onSkip) { Text("Not now").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity) }
            }.padding(Spacing.s7)
        }
    }
}
