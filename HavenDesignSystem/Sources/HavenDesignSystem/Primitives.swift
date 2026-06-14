/// Layer 1 — the ONLY place raw color values live. Internal to the module.
enum Primitives {
    // Brand · orange (the "spark")
    static let orange600 = RGBA(hex: 0xec6a1e)
    static let orange500 = RGBA(hex: 0xef6a20)
    static let orange300 = RGBA(hex: 0xe89766)
    static let orangeInk = RGBA(hex: 0x1c0f06)

    // Warm charcoal · dark surfaces
    static let charcoal950 = RGBA(hex: 0x15110d)
    static let charcoal900 = RGBA(hex: 0x1c1712)
    static let charcoal870 = RGBA(hex: 0x1d1711)
    static let charcoal850 = RGBA(hex: 0x211a14)
    static let charcoal820 = RGBA(hex: 0x272019)
    static let charcoal800 = RGBA(hex: 0x2f271e)
    static let charcoal780 = RGBA(hex: 0x2c241c)
    static let charcoal760 = RGBA(hex: 0x322a21)
    static let charcoal740 = RGBA(hex: 0x322619)

    // Warm creams / sands · light text + dark-theme ink
    static let cream50  = RGBA(hex: 0xf4ede4)
    static let cream100 = RGBA(hex: 0xf3ece3)
    static let cream200 = RGBA(hex: 0xefe7df)
    static let sand300  = RGBA(hex: 0xc3b7a9)
    static let sand400  = RGBA(hex: 0xb3a799)
    static let sand500  = RGBA(hex: 0xa99c8c)
    static let taupe500 = RGBA(hex: 0x9a8d7e)
    static let taupe600 = RGBA(hex: 0x74695c)

    // Warm paper · light surfaces
    static let paper50    = RGBA(hex: 0xf1ece4)
    static let paper100   = RGBA(hex: 0xe7e0d6)
    static let paper200   = RGBA(hex: 0xe3dccf)
    static let paper300   = RGBA(hex: 0xddd5c8)
    static let paperPeach = RGBA(hex: 0xf8e0cf)
    static let ink900     = RGBA(hex: 0x1d1813)
    static let ink700     = RGBA(hex: 0x34302a)
    static let stone500   = RGBA(hex: 0x8c8073)
    static let stone400   = RGBA(hex: 0xb0a597)

    // Semantic hues · factor rings + weather risk
    static let sageDark    = RGBA(hex: 0x8a9966)
    static let sageLight   = RGBA(hex: 0x7f8a5d)
    static let amberDark   = RGBA(hex: 0xd79a4e)
    static let amberLight  = RGBA(hex: 0xc2873a)
    static let amberInkDark  = RGBA(hex: 0xd9a560)
    static let amberInkLight = RGBA(hex: 0x9c6a26)
    static let clayDark    = RGBA(hex: 0xcf7551)
    static let clayLight   = RGBA(hex: 0xbd6446)
}
