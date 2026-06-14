import SwiftUI

public struct TextStyle: Sendable {
    public let family: FontFamily
    public let size: CGFloat
    public let weight: FontWeightToken
    public let leading: CGFloat      // multiple
    public let trackingEm: CGFloat   // em
    public var uppercased: Bool = false

    public var kerning: CGFloat { trackingEm * size }
    public var lineSpacing: CGFloat { size * (leading - 1) }

    var uiWeight: Font.Weight {
        switch weight { case .regular: .regular; case .medium: .medium; case .semibold: .semibold; case .bold: .bold }
    }
    var font: Font {
        Font.custom(family.fontName(weight: weight), size: size).weight(uiWeight)
    }

    // Named styles (from HavenDesignSystem/README.md)
    public static let screenTitle = TextStyle(family: .serif, size: TypeScale.title, weight: .semibold, leading: Leading.tight, trackingEm: Tracking.tight)
    public static let riskWord    = TextStyle(family: .serif, size: TypeScale.display, weight: .semibold, leading: Leading.tight, trackingEm: Tracking.tight)
    public static let sectionHead = TextStyle(family: .sans, size: TypeScale.md, weight: .semibold, leading: Leading.snug, trackingEm: Tracking.snug)
    public static let body        = TextStyle(family: .sans, size: TypeScale.base, weight: .regular, leading: Leading.normal, trackingEm: 0)
    public static let meta        = TextStyle(family: .sans, size: TypeScale.sm, weight: .medium, leading: Leading.snug, trackingEm: 0)
    public static let columnLabel = TextStyle(family: .sans, size: TypeScale.lg, weight: .semibold, leading: Leading.snug, trackingEm: Tracking.snug)
    public static let eyebrow     = TextStyle(family: .sans, size: TypeScale.xs, weight: .semibold, leading: Leading.snug, trackingEm: Tracking.wide, uppercased: true)
}

public extension View {
    func havenText(_ style: TextStyle, color: Color) -> some View {
        self.font(style.font)
            .kerning(style.kerning)
            .lineSpacing(style.lineSpacing)
            .textCase(style.uppercased ? .uppercase : nil)
            .foregroundStyle(color)
    }
}

public extension Text {
    /// Convenience so `Text(...).havenText(...)` reads naturally.
    func havenText(_ style: TextStyle, color: Color) -> some View {
        (self as Text).font(style.font)
            .kerning(style.kerning)
            .lineSpacing(style.lineSpacing)
            .textCase(style.uppercased ? .uppercase : nil)
            .foregroundStyle(color)
    }
}
