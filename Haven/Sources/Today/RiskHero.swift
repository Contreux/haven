import SwiftUI
import HavenDesignSystem
import HavenCore

struct RiskHero: View {
    @Environment(\.theme) private var theme
    let weather: Weather

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("WEATHER RISK").havenText(.eyebrow, color: theme.riskInk)
            Text(weather.headline).havenText(.riskWord, color: theme.risk)
            gauge
            Text(weather.detail).havenText(.body, color: theme.riskInk)
        }
        .padding(Spacing.s7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.riskBg, in: RoundedRectangle(cornerRadius: Radius.xxl))
    }

    private var gauge: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(i < weather.bars ? theme.risk : theme.track)
                    .frame(height: Spacing.s3)
            }
        }
    }
}
