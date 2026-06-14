import CoreGraphics

public enum FontWeightToken: Sendable { case regular, medium, semibold, bold }

public enum FontFamily: Sendable {
    case serif   // Source Serif 4
    case sans    // Hanken Grotesk

    /// PostScript family base; weight selection is applied by the variable font.
    public func fontName(weight: FontWeightToken) -> String {
        switch self {
        case .serif: return "SourceSerif4"
        case .sans:  return "HankenGrotesk"
        }
    }
}

/// Type sizes (pt), tuned to the 372-pt design frame.
public enum TypeScale {
    public static let xs: CGFloat = 11
    public static let sm: CGFloat = 12.5
    public static let base: CGFloat = 13.5
    public static let md: CGFloat = 15
    public static let lg: CGFloat = 19
    public static let title: CGFloat = 34   // serif
    public static let display: CGFloat = 31 // serif
}

public enum Leading {            // line-height multiples
    public static let tight: CGFloat = 1.06
    public static let snug: CGFloat = 1.4
    public static let normal: CGFloat = 1.55
}

public enum Tracking {           // letter-spacing in em
    public static let tight: CGFloat = -0.015
    public static let snug: CGFloat = -0.01
    public static let wide: CGFloat = 0.14
}
