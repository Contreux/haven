import SwiftUI

public enum FactorLevel: Sendable { case good, mid, high
    // Aliases matching trigger/severity language used across the app.
    public static let low = FactorLevel.good
    public static let medium = FactorLevel.mid
}

public struct Theme: Sendable {
    // Stored RGBA tokens (testable). Views use the Color accessors below.
    let bgToken, surfaceToken, chipToken, inkToken, inkSoftToken, inkFaintToken, hairlineToken, trackToken: RGBA
    let accentToken, streakBgToken: RGBA
    let riskToken, riskBgToken, riskInkToken: RGBA
    let ctaBgToken, ctaInkToken: RGBA
    let tabbarBgToken, tabActiveBgToken, tabActiveInkToken: RGBA
    let factorGoodToken, factorMidToken, factorHighToken: RGBA
    public let ctaShadow: ShadowToken

    // MARK: Color accessors (what feature code uses)
    public var bg: Color { bgToken.color }
    public var surface: Color { surfaceToken.color }
    public var chip: Color { chipToken.color }
    public var ink: Color { inkToken.color }
    public var inkSoft: Color { inkSoftToken.color }
    public var inkFaint: Color { inkFaintToken.color }
    public var hairline: Color { hairlineToken.color }
    public var track: Color { trackToken.color }
    public var accent: Color { accentToken.color }
    public var streakBg: Color { streakBgToken.color }
    public var risk: Color { riskToken.color }
    public var riskBg: Color { riskBgToken.color }
    public var riskInk: Color { riskInkToken.color }
    public var ctaBg: Color { ctaBgToken.color }
    public var ctaInk: Color { ctaInkToken.color }
    public var tabbarBg: Color { tabbarBgToken.color }
    public var tabActiveBg: Color { tabActiveBgToken.color }
    public var tabActiveInk: Color { tabActiveInkToken.color }
    public var factorGood: Color { factorGoodToken.color }
    public var factorMid: Color { factorMidToken.color }
    public var factorHigh: Color { factorHighToken.color }

    func factorColorToken(for level: FactorLevel) -> RGBA {
        switch level {
        case .good: return factorGoodToken
        case .mid:  return factorMidToken
        case .high: return factorHighToken
        }
    }
    public func factorColor(for level: FactorLevel) -> Color { factorColorToken(for: level).color }

    // MARK: Themes (1:1 with .theme-dark / .theme-light)
    public static let dark = Theme(
        bgToken: Primitives.charcoal900, surfaceToken: Primitives.charcoal820, chipToken: Primitives.charcoal820,
        inkToken: Primitives.cream100, inkSoftToken: Primitives.sand500, inkFaintToken: Primitives.taupe600,
        hairlineToken: Primitives.charcoal780, trackToken: Primitives.charcoal760,
        accentToken: Primitives.orange500, streakBgToken: RGBA(hex: 0xef6a20, alpha: 0.14),
        riskToken: Primitives.amberDark, riskBgToken: RGBA(hex: 0xd79a4e, alpha: 0.15), riskInkToken: Primitives.amberInkDark,
        ctaBgToken: Primitives.orange500, ctaInkToken: Primitives.orangeInk,
        tabbarBgToken: RGBA(hex: 0x1c1712, alpha: 0.86), tabActiveBgToken: Primitives.charcoal800, tabActiveInkToken: Primitives.cream100,
        factorGoodToken: Primitives.sageDark, factorMidToken: Primitives.amberDark, factorHighToken: Primitives.clayDark,
        ctaShadow: ShadowToken(color: RGBA(hex: 0xef6a20, alpha: 0.6), radius: 26, x: 0, y: 8)
    )

    public static let light = Theme(
        bgToken: Primitives.paper50, surfaceToken: Primitives.paper100, chipToken: Primitives.paper100,
        inkToken: Primitives.ink900, inkSoftToken: Primitives.stone500, inkFaintToken: Primitives.stone400,
        hairlineToken: Primitives.paper200, trackToken: Primitives.paper300,
        accentToken: Primitives.orange600, streakBgToken: Primitives.paperPeach,
        riskToken: Primitives.amberLight, riskBgToken: RGBA(hex: 0xf0e2cd), riskInkToken: Primitives.amberInkLight,
        ctaBgToken: Primitives.ink700, ctaInkToken: Primitives.cream50,
        tabbarBgToken: RGBA(hex: 0xf1ece4, alpha: 0.86), tabActiveBgToken: RGBA(hex: 0x2f2a24), tabActiveInkToken: Primitives.cream100,
        factorGoodToken: Primitives.sageLight, factorMidToken: Primitives.amberLight, factorHighToken: Primitives.clayLight,
        ctaShadow: ShadowToken(color: RGBA(hex: 0x34302a, alpha: 0.5), radius: 22, x: 0, y: 8)
    )
}

public struct ShadowToken: Sendable {
    let color: RGBA
    public let radius, x, y: CGFloat
    public var swiftUIColor: Color { color.color }
}
