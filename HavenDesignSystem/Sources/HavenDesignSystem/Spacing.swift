import CoreGraphics

/// Layer 2 — theme-agnostic spacing scale (points). From the GLOBAL TOKENS block.
public enum Spacing {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 6
    public static let s3: CGFloat = 9
    public static let s4: CGFloat = 11
    public static let s5: CGFloat = 14
    public static let s6: CGFloat = 16
    public static let s7: CGFloat = 20
    public static let s8: CGFloat = 22
    // s9 intentionally omitted — the source scale jumps s8 → s10.
    public static let s10: CGFloat = 30
}
