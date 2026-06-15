import SwiftUI
import HavenDesignSystem
import HavenCore

struct WeatherScreen: View {
    @Environment(\.theme) private var theme
    let weather: Weather

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("Weather").havenText(.screenTitle, color: theme.ink)
                    RiskHero(weather: weather)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s4), GridItem(.flexible(), spacing: Spacing.s4)], spacing: Spacing.s4) {
                        cell(icon: "gauge", k: "Pressure swing", v: "\(weather.swing)", unit: "hPa", t: trendLabel, spark: weather.pressureTrend)
                        cell(icon: "thermometer", k: "Temp swing", v: "\(weather.tempSwing)", unit: "°", t: "Now \(weather.temp)°", spark: [])
                        cell(icon: "drop", k: "Humidity", v: "\(weather.humidity)", unit: "%", t: "Logged, not led on", spark: [])
                        cell(icon: "wind", k: "Wind", v: "—", unit: "mph", t: "Light", spark: [])
                    }
                    noteCard
                }.padding(Spacing.s6)
            }
        }
    }

    private var trendLabel: String { weather.trend == "falling" ? "Falling — strongest signal" : weather.trend.capitalized }

    private func cell(icon: String, k: String, v: String, unit: String, t: String, spark: [Double]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: Spacing.s2) { Image(systemName: icon).foregroundStyle(theme.inkSoft); Text(k).havenText(.eyebrow, color: theme.inkFaint) }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
                Text(v).havenText(.riskWord, color: theme.ink)
                Text(unit).havenText(.meta, color: theme.inkSoft)
            }
            Text(t).havenText(.meta, color: theme.inkSoft)
            if !spark.isEmpty { Sparkline(values: spark).frame(height: Spacing.s8) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s5).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: Spacing.s2) { Image(systemName: "cloud").foregroundStyle(theme.accent); Text("Why this matters").havenText(.sectionHead, color: theme.ink) }
            Text("Pressure and temperature are the strongest recurring weather signals in the research. When barometric pressure drops quickly, the change can set off attacks in sensitive people. Humidity is logged but not led on.")
                .havenText(.body, color: theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s5).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
    }
}

struct Sparkline: View {
    @Environment(\.theme) private var theme
    let values: [Double]
    var body: some View {
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        HStack(alignment: .bottom, spacing: Spacing.s1) {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                let frac = (hi - lo) == 0 ? 0.5 : (v - lo) / (hi - lo)
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(i >= values.count - 3 ? theme.risk : theme.track)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing.s2 + CGFloat(frac) * Spacing.s7)
            }
        }
    }
}
