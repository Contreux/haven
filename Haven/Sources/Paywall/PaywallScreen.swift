import SwiftUI
import StoreKit
import HavenDesignSystem

struct PaywallScreen: View {
    @Environment(\.theme) private var theme
    let store: StoreService
    let onSubscribe: (String) -> Void   // productID
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var plan = "haven.yearly"
    private let feats = [
        ("sparkles", "AI trigger analysis on every meal you log"),
        ("cloud", "Barometric weather-risk forecasts"),
        ("book", "Unlimited history & doctor-ready reports"),
        ("chart.line.uptrend.xyaxis", "Personal pattern insights that sharpen over time"),
    ]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                HStack { Spacer(); Button(action: onClose) { Image(systemName: "xmark").foregroundStyle(theme.inkSoft) } }
                Image(systemName: "flame.fill").imageScale(.large).foregroundStyle(theme.accent)
                Text("Start finding your triggers").havenText(.screenTitle, color: theme.ink)
                Text("Your profile's ready. Unlock the tools that turn daily logs into real answers.").havenText(.body, color: theme.inkSoft)
                ForEach(feats, id: \.1) { icon, t in
                    HStack(spacing: Spacing.s3) { Image(systemName: icon).foregroundStyle(theme.accent); Text(t).havenText(.body, color: theme.ink) }
                }
                planRow("haven.yearly", name: "Yearly", meta: "$83.20 billed once a year", price: "$1.60", unit: "per week", badge: "SAVE 87% · 7 DAYS FREE")
                planRow("haven.weekly", name: "Weekly", meta: "Billed every week", price: "$12", unit: "per week", badge: nil)
                Spacer()
                Button { onSubscribe(plan) } label: {
                    Text(plan == "haven.yearly" ? "Start 7-day free trial" : "Subscribe weekly")
                        .havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }.accessibilityIdentifier("pay-subscribe")
                Text(plan == "haven.yearly" ? "7 days free, then $83.20/year. Cancel anytime." : "$12 per week. Cancel anytime.")
                    .havenText(.meta, color: theme.inkFaint)
                HStack(spacing: Spacing.s5) {
                    Button(action: onRestore) { Text("Restore").havenText(.meta, color: theme.inkSoft) }
                        .accessibilityIdentifier("pay-restore")
                    Button(action: onClose) { Text("Terms").havenText(.meta, color: theme.inkSoft) }
                    Button(action: onClose) { Text("Privacy").havenText(.meta, color: theme.inkSoft) }
                }.frame(maxWidth: .infinity)
            }.padding(Spacing.s7)
        }
        .task { await store.load() }
    }

    private func planRow(_ id: String, name: String, meta: String, price: String, unit: String, badge: String?) -> some View {
        let on = plan == id
        let displayPrice = store.product(id)?.displayPrice ?? price
        return Button { plan = id } label: {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                if let badge { Text(badge).havenText(.eyebrow, color: theme.accent) }
                HStack {
                    VStack(alignment: .leading) {
                        Text(name).havenText(.sectionHead, color: theme.ink)
                        Text(meta).havenText(.meta, color: theme.inkSoft)
                    }
                    Spacer()
                    Text(displayPrice).havenText(.sectionHead, color: theme.ink)
                }
            }
            .padding(Spacing.s5).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(on ? theme.accent : theme.hairline, lineWidth: on ? 2 : 1))
        }
        .accessibilityIdentifier("plan-\(id)")
    }
}
