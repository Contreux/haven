import SwiftUI
import HavenCore

struct MenuScanSheet: View {
    let scanMenu: (Data) async -> MenuScan
    let onLog: (FoodEntry) async -> Void
    var body: some View { Text("Menu scanner") }
}
