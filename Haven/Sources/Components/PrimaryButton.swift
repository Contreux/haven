import SwiftUI
import HavenDesignSystem

/// The design's full-width primary CTA (`.btn.btn-primary.btn-block`): cta fill, radius-lg,
/// 16px block padding, the cta drop-shadow, and a 0.45-opacity dim when disabled
/// (`.btn:disabled{opacity:.45}`). Apply to a Button's label; the label keeps its own
/// `theme.ctaInk` foreground. Reads `\.isEnabled`, so put `.disabled(...)` on the Button.
private struct PrimaryCTA: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)   // .btn-block padding
            .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            // cta-shadow: 0 8px 26px -10px — the negative spread keeps it tight, so use a
            // moderate blur rather than the full token radius (which has no SwiftUI equivalent).
            .shadow(color: theme.ctaShadow.swiftUIColor, radius: 16, x: 0, y: 8)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// The design's full-width secondary CTA (`.btn.btn-ghost`): chip fill, radius-lg, 16px
/// block padding, no shadow, no border, dimming to 0.45 when disabled. The label keeps its
/// own `theme.ink` foreground.
private struct SecondaryCTA: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.chip, in: RoundedRectangle(cornerRadius: Radius.lg))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

extension View {
    /// Style a Button label as the design's full-width primary CTA. See `PrimaryCTA`.
    func primaryCTA() -> some View { modifier(PrimaryCTA()) }
    /// Style a Button label as the design's full-width secondary (ghost) CTA. See `SecondaryCTA`.
    func secondaryCTA() -> some View { modifier(SecondaryCTA()) }
}
