import SwiftUI
import PhotosUI
import HavenDesignSystem
import HavenCore

struct FoodCaptureSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let analyze: (String) async -> AnalyzedFood
    let analyzeImage: (Data, String) async -> AnalyzedFood
    let onSave: (FoodEntry, Data?) async -> Void
    var initialMode: Mode = .describe

    enum Mode: String { case describe = "Describe", photo = "Photo", camera = "Camera" }
    @State private var mode: Mode
    @State private var desc = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var busy = false
    @State private var saving = false
    @State private var showCamera = false
    @State private var result: AnalyzedFood?

    init(analyze: @escaping (String) async -> AnalyzedFood,
         analyzeImage: @escaping (Data, String) async -> AnalyzedFood,
         onSave: @escaping (FoodEntry, Data?) async -> Void,
         initialMode: Mode = .describe) {
        self.analyze = analyze; self.analyzeImage = analyzeImage; self.onSave = onSave
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

    private var canAnalyze: Bool { mode == .describe ? desc.trimmingCharacters(in: .whitespaces).count > 1 : (imageData != nil || desc.count > 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            SheetHeader(title: "Log food", subtitle: "Snap, choose a photo, or describe what you ate")
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

    private var captureView: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Segmented(options: [Mode.describe.rawValue, Mode.photo.rawValue, Mode.camera.rawValue],
                      selection: Binding(get: { mode.rawValue },
                                         set: { mode = Mode(rawValue: $0) ?? .describe }))
            switch mode {
            case .describe:
                TextField("Describe what you ate or drank…", text: $desc, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .padding(Spacing.s3).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    .havenText(.body, color: theme.ink)
            case .photo:
                PhotosPicker(selection: $photoItem, matching: .images) {
                    CaptureTile(icon: "photo.on.rectangle", label: imageData == nil ? "Choose a photo" : "Choose a different photo")
                }
                .onChange(of: photoItem) { _, item in
                    Task {
                        if let raw = try? await item?.loadTransferable(type: Data.self) {
                            imageData = ImageScaler.downscaledJPEG(raw)
                        }
                    }
                }
                attachedBlock
            case .camera:
                Button { showCamera = true } label: {
                    CaptureTile(icon: "camera.fill", label: imageData == nil ? "Take a photo" : "Retake photo")
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraPicker { data in if let data { imageData = ImageScaler.downscaledJPEG(data) } }
                        .ignoresSafeArea()
                }
                attachedBlock
            }
            Button {
                busy = true
                Task {
                    let t0 = Date()
                    let r: AnalyzedFood
                    if let data = imageData {
                        r = await analyzeImage(data, desc)
                    } else {
                        let text = desc.isEmpty ? "the meal in the photo" : desc
                        r = await analyze(text)
                    }
                    await Self.thinkingBeat(since: t0)
                    busy = false
                    withAnimation(.easeOut(duration: 0.3)) { result = r }
                }
            } label: {
                HStack(spacing: Spacing.s3) {
                    if busy { ProgressView().tint(theme.ctaInk) }
                    Text(busy ? "Analyzing" : "Analyze").havenText(.sectionHead, color: theme.ctaInk)
                }
                .primaryCTA()
            }
            .disabled(busy || !canAnalyze)
            .accessibilityIdentifier("food-analyze")
            Text("Trigger assessments are informational and may be wrong.")
                .havenText(.meta, color: theme.inkFaint)
        }
    }

    /// Shown once an image is attached (photo or camera): confirmation + optional description.
    @ViewBuilder private var attachedBlock: some View {
        if imageData != nil {
            Label("Photo attached", systemImage: "checkmark.circle.fill")
                .havenText(.meta, color: theme.factorGood)
            TextField("Optional: describe the meal…", text: $desc)
                .padding(Spacing.s3).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .havenText(.body, color: theme.ink)
        }
    }

    private func resultView(_ r: AnalyzedFood) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text(r.label).havenText(.sectionHead, color: theme.ink)
            if !r.note.isEmpty { Text(r.note).havenText(.meta, color: theme.inkSoft) }
            if !r.items.isEmpty {
                Text("ITEMS DETECTED").havenText(.eyebrow, color: theme.inkFaint)
                ForEach(r.items, id: \.self) { item in
                    HStack(spacing: Spacing.s3) {
                        Image(systemName: "fork.knife").foregroundStyle(theme.inkSoft)
                        Text(item).havenText(.body, color: theme.ink)
                    }
                    .padding(.vertical, Spacing.s1)
                }
            }
            Text("TRIGGERS DETECTED").havenText(.eyebrow, color: theme.inkFaint)
            if r.triggers.isEmpty {
                HStack { Image(systemName: "checkmark.circle"); Text("No obvious dietary triggers").havenText(.body, color: theme.inkSoft) }
            } else {
                ForEach(r.triggers) { t in
                    HStack(alignment: .top, spacing: Spacing.s3) {
                        LevelDot(level: t.level).padding(.top, Spacing.s2)
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            HStack { Text(t.label).havenText(.body, color: theme.ink); Spacer(); Text(t.level.rawValue).havenText(.meta, color: theme.inkSoft) }
                            if let reason = t.reason, !reason.isEmpty { Text(reason).havenText(.meta, color: theme.inkFaint) }
                        }
                    }
                    .padding(Spacing.s4).frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                }
            }
            Button {
                saving = true
                Task {
                    let food = FoodEntry(name: r.label, time: TodayStore.nowHM(), triggers: r.triggers,
                                         note: desc.isEmpty ? nil : desc, imageId: nil)
                    await onSave(food, imageData)
                    saving = false
                    dismiss()
                }
            } label: {
                HStack(spacing: Spacing.s3) {
                    if saving { ProgressView().tint(theme.ctaInk) }
                    Text(saving ? "Saving" : "Save to today").havenText(.sectionHead, color: theme.ctaInk)
                }
                .primaryCTA()
            }
            .disabled(saving)
            .accessibilityIdentifier("food-save")
            Button { withAnimation(.easeOut(duration: 0.3)) { result = nil } } label: {
                Text("Redo").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
            }
            .disabled(saving)
        }
    }

    /// Hold the spinner for a minimum beat so a fast response still reads as "thinking", per the handoff.
    static func thinkingBeat(since start: Date, minimum: TimeInterval = 0.9) async {
        let remaining = minimum - Date().timeIntervalSince(start)
        if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
    }
}

/// The tappable photo/camera tile used by the photo and camera modes.
private struct CaptureTile: View {
    @Environment(\.theme) private var theme
    let icon: String
    let label: String
    var body: some View {
        HStack(spacing: Spacing.s2) { Image(systemName: icon); Text(label).havenText(.meta, color: theme.ink) }
            .frame(maxWidth: .infinity).padding(.vertical, Spacing.s7)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .foregroundStyle(theme.inkSoft)
    }
}
