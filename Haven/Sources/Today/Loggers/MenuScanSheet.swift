import SwiftUI
import PhotosUI
import HavenDesignSystem
import HavenCore

struct MenuScanSheet: View {
    @Environment(\.theme) private var theme
    let scanMenu: (Data) async -> MenuScan
    let onLog: (FoodEntry) async -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var busy = false
    @State private var result: MenuScan?
    @State private var loggedDishes: Set<String> = []   // dish.id of dishes already logged

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    SheetHeader(title: "Scan menu", subtitle: "Photo a menu — see what's safe")
                    if let result {
                        resultView(result)
                    } else {
                        captureView
                    }
                }
                .padding(Spacing.s6)
            }
        }
    }

    private var captureView: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack { Image(systemName: "doc.text.viewfinder"); Text("Add a menu photo").havenText(.meta, color: theme.ink) }
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s7)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    .foregroundStyle(theme.inkSoft)
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let raw = try? await item?.loadTransferable(type: Data.self) {
                        imageData = ImageScaler.downscaledJPEG(raw)
                    }
                }
            }
            if imageData != nil { Text("Photo attached").havenText(.meta, color: theme.inkSoft) }
            Button {
                guard let data = imageData else { return }
                busy = true
                Task { result = await scanMenu(data); busy = false }
            } label: {
                HStack { if busy { ProgressView() }; Text(busy ? "Scanning" : "Scan menu").havenText(.sectionHead, color: theme.ctaInk) }
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                    .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            }
            .disabled(busy || imageData == nil)
            .accessibilityIdentifier("menu-scan")
            Text("Assessments are informational and may be wrong.").havenText(.meta, color: theme.inkFaint)
        }
    }

    @ViewBuilder private func resultView(_ scan: MenuScan) -> some View {
        if scan.dishes.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Couldn't read that menu").havenText(.sectionHead, color: theme.ink)
                Text("Try a clearer, well-lit photo of the menu text.").havenText(.body, color: theme.inkSoft)
                redoButton
            }
        } else {
            let g = scan.grouped()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("\(scan.dishes.count) dishes · \(g.canEat.count) you can eat")
                    .havenText(.meta, color: theme.inkSoft)
                if g.lead == .cantEat {
                    section("BEST TO AVOID", g.cantEat)
                    section("YOU CAN EAT", g.canEat)
                } else {
                    section("YOU CAN EAT", g.canEat)
                    section("BEST TO AVOID", g.cantEat)
                }
                redoButton
                Text("Tap a dish to log it. Assessments are informational and may be wrong.")
                    .havenText(.meta, color: theme.inkFaint)
            }
        }
    }

    @ViewBuilder private func section(_ title: String, _ dishes: [MenuDish]) -> some View {
        if !dishes.isEmpty {
            Text(title).havenText(.eyebrow, color: theme.inkFaint)
            ForEach(Array(dishes.enumerated()), id: \.element.id) { index, dish in
                Button {
                    Task {
                        await onLog(FoodEntry(name: dish.name, time: TodayStore.nowHM(),
                                              triggers: dish.asTriggerChips(), note: "From menu scan", imageId: nil))
                        loggedDishes.insert(dish.id)
                    }
                } label: { dishRow(dish) }
                .accessibilityIdentifier("menu-dish-\(index)")
            }
        }
    }

    private func dishRow(_ dish: MenuDish) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Circle().fill(color(for: dish.verdict)).frame(width: 10, height: 10).padding(.top, Spacing.s2)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                HStack {
                    Text(dish.name).havenText(.body, color: theme.ink)
                    Spacer()
                    if loggedDishes.contains(dish.id) {
                        Label("Logged", systemImage: "checkmark").havenText(.meta, color: theme.inkSoft)
                    }
                }
                if !dish.reason.isEmpty { Text(dish.reason).havenText(.meta, color: theme.inkFaint) }
            }
        }
        .padding(Spacing.s4).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private func color(for verdict: DishVerdict) -> Color {
        switch verdict {
        case .safe: return theme.factorColor(for: .good)
        case .caution: return theme.factorColor(for: .mid)
        case .avoid: return theme.factorColor(for: .high)
        }
    }

    private var redoButton: some View {
        Button { result = nil; imageData = nil; photoItem = nil; loggedDishes = [] } label: {
            Text("Scan another").havenText(.meta, color: theme.inkSoft)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
        }
    }
}
