import SwiftUI
import PhotosUI
import HavenDesignSystem
import HavenCore

struct FoodCaptureSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let analyze: (String) async -> AnalyzedFood
    let onSave: (FoodEntry, Data?) async -> Void

    enum Mode { case describe, photo }
    @State private var mode: Mode = .describe
    @State private var desc = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var busy = false
    @State private var result: AnalyzedFood?

    private var canAnalyze: Bool { mode == .describe ? desc.trimmingCharacters(in: .whitespaces).count > 1 : (imageData != nil || desc.count > 1) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                SheetHeader(title: "Log food", subtitle: "Photo or describe what you ate")
                if let result {
                    resultView(result)
                } else {
                    captureView
                }
                Spacer()
            }
            .padding(Spacing.s6)
        }
    }

    private var captureView: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Segmented(options: ["Describe", "Photo"], selection: Binding(
                get: { mode == .describe ? "Describe" : "Photo" },
                set: { mode = $0 == "Photo" ? .photo : .describe }))
            if mode == .describe {
                TextField("Describe what you ate or drank…", text: $desc, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .padding(Spacing.s3).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    .havenText(.body, color: theme.ink)
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack { Image(systemName: "camera"); Text("Add a photo").havenText(.meta, color: theme.ink) }
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s7)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                        .foregroundStyle(theme.inkSoft)
                }
                .onChange(of: photoItem) { _, item in
                    Task { imageData = try? await item?.loadTransferable(type: Data.self) }
                }
                if imageData != nil {
                    Text("Photo attached").havenText(.meta, color: theme.inkSoft)
                    TextField("Optional: describe the meal…", text: $desc)
                        .padding(Spacing.s3).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                        .havenText(.body, color: theme.ink)
                }
            }
            Button {
                busy = true
                Task {
                    let text = desc.isEmpty ? "the meal in the photo" : desc
                    result = await analyze(text); busy = false
                }
            } label: {
                HStack { if busy { ProgressView() }; Text(busy ? "Analyzing" : "Analyze").havenText(.sectionHead, color: theme.ctaInk) }
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                    .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            }
            .disabled(busy || !canAnalyze)
            .accessibilityIdentifier("food-analyze")
            Text("Trigger assessments are informational and may be wrong.")
                .havenText(.meta, color: theme.inkFaint)
        }
    }

    private func resultView(_ r: AnalyzedFood) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text(r.label).havenText(.sectionHead, color: theme.ink)
            if !r.note.isEmpty { Text(r.note).havenText(.meta, color: theme.inkSoft) }
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
                Task {
                    let food = FoodEntry(name: r.label, time: TodayStore.nowHM(), triggers: r.triggers,
                                         note: desc.isEmpty ? nil : desc, imageId: nil)
                    await onSave(food, imageData); dismiss()
                }
            } label: {
                Text("Save to today").havenText(.sectionHead, color: theme.ctaInk)
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                    .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
            }
            .accessibilityIdentifier("food-save")
            Button { result = nil } label: {
                Text("Redo").havenText(.meta, color: theme.inkSoft).frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
            }
        }
    }
}
