import SwiftUI
import PhotosUI
import HavenDesignSystem
import HavenCore

struct MenuScanSheet: View {
    @Environment(\.theme) private var theme
    let scanMenu: (Data) async -> MenuScan

    @StateObject private var camera = MenuCameraModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var busy = false
    @State private var result: MenuScan?
    @State private var loaderStep = 0
    @State private var showBreakdown = false

    private static let loaderSteps = ["Reading the menu…", "Spotting triggers…", "Annotating…"]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    SheetHeader(title: "Scan menu", subtitle: "Photo a menu — see what's safe")
                    if busy {
                        stagedLoader
                    } else if let result {
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

    private var stagedLoader: some View {
        VStack(spacing: Spacing.s4) {
            ProgressView().controlSize(.large).tint(theme.accent)
            Text(Self.loaderSteps[loaderStep % Self.loaderSteps.count])
                .havenText(.sectionHead, color: theme.ink)
                .contentTransition(.opacity)
            Text("This can take up to a minute.").havenText(.meta, color: theme.inkFaint)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s10)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { loaderStep += 1 }
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
            CameraViewfinder(camera: camera, height: 380, prompt: "Point your camera at the menu") { data in
                imageData = ImageScaler.downscaledJPEG(data); camera.stop()
            }
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
                Text("Scan menu").havenText(.sectionHead, color: theme.ctaInk).primaryCTA()
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
        if let urlString = scan.annotatedUrl, let url = URL(string: urlString) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Annotated menu").havenText(.sectionHead, color: theme.ink)
                ZoomableImage(url: url)
                    .frame(maxWidth: .infinity).frame(height: 460)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                if !scan.dishes.isEmpty {
                    Button { withAnimation { showBreakdown.toggle() } } label: {
                        HStack(spacing: Spacing.s2) {
                            Text(showBreakdown ? "Hide text breakdown" : "See text breakdown").havenText(.meta, color: theme.accent)
                            Image(systemName: showBreakdown ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.accent)
                        }
                    }
                    if showBreakdown { breakdownList(scan) }
                }
                redoButton
                Text("Potential triggers vary by person. Ask staff if unsure.").havenText(.meta, color: theme.inkFaint)
            }
        } else if !scan.dishes.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Couldn't annotate the image — here's the text breakdown.").havenText(.body, color: theme.inkSoft)
                breakdownList(scan)
                redoButton
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Couldn't read that menu").havenText(.sectionHead, color: theme.ink)
                Text("Try a clearer, well-lit photo of the menu text.").havenText(.body, color: theme.inkSoft)
                redoButton
            }
        }
    }

    // Read-only Safe/Caution/Avoid breakdown (no logging in v2).
    @ViewBuilder private func breakdownList(_ scan: MenuScan) -> some View {
        let g = scan.grouped()
        VStack(alignment: .leading, spacing: Spacing.s4) {
            if g.lead == .cantEat {
                breakdownSection("BEST TO AVOID", g.cantEat)
                breakdownSection("YOU CAN EAT", g.canEat)
            } else {
                breakdownSection("YOU CAN EAT", g.canEat)
                breakdownSection("BEST TO AVOID", g.cantEat)
            }
        }
    }

    @ViewBuilder private func breakdownSection(_ title: String, _ dishes: [MenuDish]) -> some View {
        if !dishes.isEmpty {
            Text(title).havenText(.eyebrow, color: theme.inkFaint)
            ForEach(Array(dishes.enumerated()), id: \.offset) { _, dish in dishRow(dish) }
        }
    }

    private func dishRow(_ dish: MenuDish) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Circle().fill(color(for: dish.verdict)).frame(width: 10, height: 10).padding(.top, Spacing.s2)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text(dish.name).havenText(.body, color: theme.ink)
                if !dish.reason.isEmpty { Text(dish.reason).havenText(.meta, color: theme.inkFaint) }
            }
            Spacer()
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
        Button { result = nil; imageData = nil; photoItem = nil; showBreakdown = false; camera.startIfPermitted() } label: {
            Text("Scan another").havenText(.meta, color: theme.inkSoft)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
        }
    }
}

/// A pinch-to-zoom, pannable async image for inspecting the dense annotated menu.
private struct ZoomableImage: View {
    @Environment(\.theme) private var theme
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { scale = min(max(1, lastScale * $0), 5) }
                                .onEnded { _ in
                                    if scale <= 1.01 {
                                        withAnimation { scale = 1; offset = .zero; lastOffset = .zero }
                                    } else {
                                        offset = clamp(offset, in: geo.size)
                                        lastOffset = offset
                                    }
                                    lastScale = scale
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged {
                                            guard scale > 1 else { return }
                                            offset = clamp(CGSize(width: lastOffset.width + $0.translation.width,
                                                                  height: lastOffset.height + $0.translation.height), in: geo.size)
                                        }
                                        .onEnded { _ in lastOffset = offset }
                                )
                        )
                case .failure:
                    Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(theme.inkFaint)
                        .frame(width: geo.size.width, height: geo.size.height)
                default:
                    ProgressView().frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .clipped()
    }

    // Keep the zoomed image from being dragged completely off-screen.
    private func clamp(_ o: CGSize, in size: CGSize) -> CGSize {
        let maxX = max(0, (scale - 1) * size.width / 2)
        let maxY = max(0, (scale - 1) * size.height / 2)
        return CGSize(width: min(max(o.width, -maxX), maxX),
                      height: min(max(o.height, -maxY), maxY))
    }
}
