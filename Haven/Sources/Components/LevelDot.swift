import SwiftUI
import HavenDesignSystem
import HavenCore

struct LevelDot: View {
    @Environment(\.theme) private var theme
    let level: Level
    var body: some View {
        Circle().fill(theme.factorColor(for: factorLevel(level))).frame(width: Spacing.s3, height: Spacing.s3)
    }
    private func factorLevel(_ l: Level) -> FactorLevel {
        switch l { case .low: .low; case .mid: .medium; case .high: .high }
    }
}
