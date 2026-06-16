import SwiftUI
import HavenDesignSystem

/// Reports the intrinsic height of a sheet's content so the sheet can size to it.
private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Presents a fan logger as a bottom sheet sized to its content (grabber, rounded top, dark surface).
/// The content must lay out at its intrinsic height (no `Spacer()` / full-bleed background).
private struct ContentSizedSheet: ViewModifier {
    @Environment(\.theme) private var theme
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)   // adopt intrinsic height, not the sheet's
            .padding(.bottom, Spacing.s5)                    // clearance above the home indicator
            .background(GeometryReader { g in
                Color.clear.preference(key: SheetHeightKey.self, value: g.size.height)
            })
            .onPreferenceChange(SheetHeightKey.self) { height = $0 }
            .presentationDetents(height > 0 ? [.height(height)] : [.medium])
            .presentationCornerRadius(28)
            .presentationBackground(theme.bg)   // grabber comes from SheetHeader, so no system indicator
    }
}

/// Bottom-sheet chrome for scrollable/dynamic content (e.g. the menu scanner) that can't size to content.
private struct BottomSheetChrome: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
            .presentationBackground(theme.bg)   // grabber comes from SheetHeader, so no system indicator
    }
}

extension View {
    func contentSizedSheet() -> some View { modifier(ContentSizedSheet()) }
    func bottomSheetChrome() -> some View { modifier(BottomSheetChrome()) }
}
