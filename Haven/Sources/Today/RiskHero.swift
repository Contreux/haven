import SwiftUI
import HavenDesignSystem
import HavenCore

struct RiskHero: View {
    @Environment(\.theme) private var theme
    let weather: Weather

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("Weather risk today").havenText(.meta, color: theme.riskInk)
            HStack(alignment: .bottom) {
                Text(weather.headline).havenText(.riskWord, color: theme.risk)
                Spacer()
                gauge
            }
            Text(weather.detail).havenText(.body, color: theme.riskInk)
        }
        .padding(Spacing.s7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.riskBg, in: RoundedRectangle(cornerRadius: Radius.xxl))
    }

    // Vertical, signal-strength style bars (ascending), matching the prototype.
    private var gauge: some View {
        HStack(alignment: .bottom, spacing: Spacing.s1) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(i < weather.bars ? theme.risk : theme.track)
                    .frame(width: Spacing.s2, height: Spacing.s3 + CGFloat(i) * Spacing.s2)
            }
        }
    }
}
