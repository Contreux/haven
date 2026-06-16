import SwiftUI
import PhotosUI
import HavenDesignSystem
import HavenCore

struct MenuScanSheet: View {
    @Environment(\.theme) private var theme
    let scanMenu: (Data) async -> MenuScan
    let onLog: (FoodEntry) async -> Void

    @StateObject private var camera = MenuCameraModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var busy = false
    @State private var result: MenuScan?
    @State private var loggedDishes: Set<String> = []   // section keys of dishes already logged
    @State private var loggingKey: String?              // section key currently being logged

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    SheetHeader(title: "Scan menu", subtitle: "Photo a menu — see what's safe")
                    if let result {
                        resultView(result)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        captureView
                            .transition(.opacity)
                    }
                }
                .padding(Spacing.s6)
            }
        }
    }

    private var captureView: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            if let data = imageData, let img = UIImage(data: data) {
                capturedView(img)
            } else {
                cameraView
            }
            Text("Assessments are informational and may be wrong.").havenText(.meta, color: theme.inkFaint)
        }
        .onAppear { camera.startIfPermitted() }
        .onDisappear { camera.stop() }
    }

    // Live camera viewfinder with a shutter, plus an album fallback.
    private var cameraView: some View {
        VStack(spacing: Spacing.s4) {
            ZStack {
                if camera.access == .granted && camera.ready {
                    CameraPreview(session: camera.session)
                } else {
                    RoundedRectangle(cornerRadius: Radius.lg).fill(theme.surface)
                        .overlay(
                            VStack(spacing: Spacing.s2) {
                                Image(systemName: camera.access == .denied ? "video.slash" : "camera.viewfinder")
                                    .font(.system(size: 28)).foregroundStyle(theme.inkFaint)
                                Text(camera.access == .denied ? "Camera access is off — enable it in Settings, or choose from your album."
                                                              : "Point your camera at the menu")
                                    .havenText(.meta, color: theme.inkFaint)
                                    .multilineTextAlignment(.center).padding(.horizontal, Spacing.s6)
                            })
                }
            }
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            // Shutter
            Button {
                camera.capture { data in
                    guard let data else { return }
                    imageData = ImageScaler.downscaledJPEG(data)
                    camera.stop()
                }
            } label: {
                ZStack {
                    Circle().fill(theme.ctaBg).frame(width: 64, height: 64)
                    Circle().stroke(theme.bg, lineWidth: 3).frame(width: 54, height: 54)
                }
            }
            .disabled(!(camera.access == .granted && camera.ready))
            .opacity(camera.access == .granted && camera.ready ? 1 : 0.4)
            .accessibilityIdentifier("menu-shutter")
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: Spacing.s2) { Image(systemName: "photo.on.rectangle"); Text("Choose from album").havenText(.meta, color: theme.ink) }
                    .foregroundStyle(theme.inkSoft)
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let raw = try? await item?.loadTransferable(type: Data.self) {
                        imageData = ImageScaler.downscaledJPEG(raw); camera.stop()
                    }
                }
            }
        }
    }

    // After a shot is taken or picked: preview + scan / retake.
    private func capturedView(_ img: UIImage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(height: 320).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            Button {
                guard let data = imageData else { return }
                busy = true
                Task {
                    let t0 = Date()
                    let scan = await scanMenu(data)
                    await FoodCaptureSheet.thinkingBeat(since: t0)
                    busy = false
                    withAnimation(.easeOut(duration: 0.3)) { result = scan }
                }
            } label: {
                HStack(spacing: Spacing.s3) {
                    if busy { ProgressView().tint(theme.ctaInk) }
                    Text(busy ? "Scanning" : "Scan menu").havenText(.sectionHead, color: theme.ctaInk)
                }
                .primaryCTA()
            }
            .disabled(busy)
            .accessibilityIdentifier("menu-scan")
            Button { imageData = nil; photoItem = nil; camera.startIfPermitted() } label: {
                Text("Retake").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
            }
            .disabled(busy)
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
                    section("BEST TO AVOID", code: "avoid", g.cantEat)
                    section("YOU CAN EAT", code: "eat", g.canEat)
                } else {
                    section("YOU CAN EAT", code: "eat", g.canEat)
                    section("BEST TO AVOID", code: "avoid", g.cantEat)
                }
                redoButton
                Text("Tap a dish to log it. Assessments are informational and may be wrong.")
                    .havenText(.meta, color: theme.inkFaint)
            }
        }
    }

    @ViewBuilder private func section(_ title: String, code: String, _ dishes: [MenuDish]) -> some View {
        if !dishes.isEmpty {
            Text(title).havenText(.eyebrow, color: theme.inkFaint)
            // Key by section code + offset so duplicate dish names stay distinct rows.
            ForEach(Array(dishes.enumerated()), id: \.offset) { index, dish in
                let key = "\(code)-\(index)"
                Button {
                    guard loggingKey == nil, !loggedDishes.contains(key) else { return }
                    loggingKey = key
                    Task {
                        await onLog(FoodEntry(name: dish.name, time: TodayStore.nowHM(),
                                              triggers: dish.asTriggerChips(), note: "From menu scan", imageId: nil))
                        loggingKey = nil
                        loggedDishes.insert(key)
                    }
                } label: { dishRow(dish, logged: loggedDishes.contains(key), logging: loggingKey == key) }
                .disabled(loggingKey != nil)
                .accessibilityIdentifier("menu-\(code)-dish-\(index)")
            }
        }
    }

    private func dishRow(_ dish: MenuDish, logged: Bool, logging: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Circle().fill(color(for: dish.verdict)).frame(width: 10, height: 10).padding(.top, Spacing.s2)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                HStack {
                    Text(dish.name).havenText(.body, color: theme.ink)
                    Spacer()
                    if logging {
                        ProgressView().controlSize(.small).tint(theme.inkSoft)
                    } else if logged {
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
