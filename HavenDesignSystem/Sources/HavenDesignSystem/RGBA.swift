import SwiftUI

/// The only color value type. Primitives are RGBA; views read `.color`.
///
/// Equality is bitwise on the `Double` channels. It is reliable for tokens built from
/// the same integer source (the `hex:` init) or identical literals — which is all this
/// module does. Do not compare *derived* colors (lerp/lighten/etc.) with `==`.
struct RGBA: Equatable, Sendable {
    let r, g, b, a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            r: Double((hex >> 16) & 0xFF) / 255.0,
            g: Double((hex >> 8) & 0xFF) / 255.0,
            b: Double(hex & 0xFF) / 255.0,
            a: alpha
        )
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}
