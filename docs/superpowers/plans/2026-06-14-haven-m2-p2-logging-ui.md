# Haven M2 · Plan 2 — Logging UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the four bottom-sheet loggers (migraine, symptoms, daily factors, food capture with two-tier AI), the center "+" speed-dial, and wire them into Today via `ConvexService` — so the user can record everything the ledger shows and watch it update reactively.

**Architecture:** Tokenized SwiftUI sheets presented from `TodayScreen`, writing through the `TodayStore` methods added in M2-P1 (backed by `ConvexService`, which now implements the extended `DayDataSource` + the `analyzeFood` action call + photo upload). Small reusable components (`Segmented`, `LevelDot`, `SheetHeader`). Verified end-to-end on the simulator via Maestro.

**Tech Stack:** Swift 6 / SwiftUI · HavenDesignSystem tokens · HavenCore (store/models/engine) · convex-swift (`action`, file upload) · Maestro.

**Reference:** spec `docs/superpowers/specs/2026-06-14-haven-m2-logging-design.md` (§7); handoff `design_handoff/prototypes/app/sheets.jsx`; M2-P1 (store methods, `AnalyzedFood`, mutations).

---

## Scope & dependencies
- **Depends on:** M2-P1 (store methods + protocol + mutations + action deployed).
- **Produces:** the working logging surface, Maestro-verified.
- **Out of scope:** Calendar/Insights/Weather tabs + full bottom nav (M3/M4).

## File structure
```
Haven/Sources/Components/
├── Segmented.swift        # token-styled segmented control (Binding<String> or generic)
├── LevelDot.swift         # colored dot by Level
└── SheetHeader.swift      # grab handle + title + subtitle
Haven/Sources/Today/Loggers/
├── MigraineSheet.swift
├── SymptomSheet.swift
├── FactorsSheet.swift     # replaces M1 FactorEditor (deleted from FactorRings.swift)
├── FoodCaptureSheet.swift
└── SpeedDial.swift        # center "+" fan
Haven/Sources/Services/ConvexService.swift   # MODIFIED: new DayDataSource methods + analyzeFood + upload
Haven/Sources/Today/TodayScreen.swift        # MODIFIED: present sheets, speed-dial, wire action buttons
Haven/Sources/Today/FactorRings.swift        # MODIFIED: remove FactorEditor (moved to FactorsSheet)
Haven/maestro/loggers.yaml
```

---

## Task 1: Verify the convex-swift `action` + file-upload API
**Files:** none (research gate — like P3-T7).

- [ ] **Step 1:** Confirm against the installed `convex-swift` 0.8.1 source (`~/Library/Developer/Xcode/DerivedData/.../SourcePackages/checkouts/convex-swift/Sources/ConvexMobile/ConvexMobile.swift`) that:
  - `func action<T: Decodable>(_ name: String, with args: [String: ConvexEncodable?]? = nil) async throws -> T` exists (it does, per earlier verification).
  - There is **no** built-in multipart upload helper — file upload is done by (a) calling the `generateUploadUrl` mutation to get a URL, then (b) a plain `URLSession` POST of the image bytes to that URL, which returns `{ storageId }`. Confirm by reading the convex docs note in the spec.
- [ ] **Step 2:** Record findings inline in the ConvexService task below. No commit.

> If `action` decoding into `AnalyzedFood` proves problematic, fall back to decoding a raw `[String: ...]` and mapping — but `AnalyzedFood` is `Codable` and the action returns its exact shape, so direct decode should work.

---

## Task 2: `Segmented` component

**Files:**
- Create: `Haven/Sources/Components/Segmented.swift`

- [ ] **Step 1: Write `Segmented.swift`**

```swift
import SwiftUI
import HavenDesignSystem

/// Token-styled segmented control over string options.
struct Segmented: View {
    @Environment(\.theme) private var theme
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { opt in
                Button { selection = opt } label: {
                    Text(opt)
                        .havenText(.meta, color: selection == opt ? theme.ctaInk : theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.s3)
                        .background(selection == opt ? theme.ctaBg : Color.clear,
                                    in: RoundedRectangle(cornerRadius: Radius.sm))
                }
            }
        }
        .padding(Spacing.s1)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    }
}
```

- [ ] **Step 2: Build** — `cd Haven && xcodegen generate && cd .. && xcodebuild -project Haven/Haven.xcodeproj -scheme Haven -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -iE 'BUILD (SUCCEEDED|FAILED)|error:'` → SUCCEEDED.
- [ ] **Step 3: Guard** — `./scripts/guard-tokens.sh` → pass. (`Color.clear` is allow-listed by the guard.)
- [ ] **Step 4: Commit** — `git add Haven/Sources/Components/Segmented.swift && git commit -m "feat: add token-styled Segmented control"`

---

## Task 3: `LevelDot` + `SheetHeader`

**Files:**
- Create: `Haven/Sources/Components/LevelDot.swift`
- Create: `Haven/Sources/Components/SheetHeader.swift`

- [ ] **Step 1: Write `LevelDot.swift`**

```swift
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
```

- [ ] **Step 2: Write `SheetHeader.swift`**

```swift
import SwiftUI
import HavenDesignSystem

struct SheetHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            RoundedRectangle(cornerRadius: Radius.pill)
                .fill(theme.hairline).frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.s2)
            Text(title).havenText(.sectionHead, color: theme.ink)
            Text(subtitle).havenText(.meta, color: theme.inkSoft)
        }
    }
}
```

- [ ] **Step 3: Build** → SUCCEEDED. **Guard** → pass.
- [ ] **Step 4: Commit** — `git add Haven/Sources/Components/LevelDot.swift Haven/Sources/Components/SheetHeader.swift && git commit -m "feat: add LevelDot and SheetHeader components"`

---

## Task 4: `ConvexService` — implement the new `DayDataSource` methods + analyzeFood + upload

**Files:**
- Modify: `Haven/Sources/Services/ConvexService.swift`

- [ ] **Step 1: Add the methods** (append inside the `ConvexService` class; uses the verified `mutation`/`action` API and a URLSession upload)

```swift
    func setMigraine(date: String, migraine: Migraine) async throws {
        let args: [String: ConvexEncodable?] = [
            "userId": userId, "date": date,
            "migraine": [
                "had": migraine.had, "severity": migraine.severity,
                "time": migraine.time, "notes": migraine.notes,
            ] as [String: ConvexEncodable?],
        ]
        try await client.mutation("days:setMigraine", with: args)
    }

    func removeMigraine(date: String) async throws {
        try await client.mutation("days:removeMigraine", with: ["userId": userId, "date": date])
    }

    func setSymptoms(date: String, symptoms: [String], loggedAt: String) async throws {
        let args: [String: ConvexEncodable?] = [
            "userId": userId, "date": date,
            "symptoms": symptoms as [ConvexEncodable?], "loggedAt": loggedAt,
        ]
        try await client.mutation("days:setSymptoms", with: args)
    }

    func addFood(date: String, food: FoodEntry) async throws {
        let triggers: [ConvexEncodable?] = food.triggers.map { t in
            [ "label": t.label, "level": t.level.rawValue, "reason": t.reason ?? "" ] as [String: ConvexEncodable?]
        }
        var foodDict: [String: ConvexEncodable?] = [
            "name": food.name, "time": food.time, "triggers": triggers, "note": food.note ?? "",
        ]
        if let imageId = food.imageId { foodDict["imageId"] = imageId }
        let args: [String: ConvexEncodable?] = ["userId": userId, "date": date, "food": foodDict]
        try await client.mutation("days:addFood", with: args)
    }

    func removeFood(date: String, foodIndex: Int) async throws {
        try await client.mutation("days:removeFood",
            with: ["userId": userId, "date": date, "foodIndex": foodIndex])
    }

    func analyzeFood(description: String) async throws -> AnalyzedFood {
        let result: AnalyzedFood = try await client.action("ai:analyzeFood", with: ["description": description])
        return result
    }

    /// Upload image bytes to Convex storage, returning the storage id (or nil on failure).
    func uploadImage(_ data: Data) async throws -> String? {
        let uploadURL: String = try await client.mutation("files:generateUploadUrl", with: [:])
        guard let url = URL(string: uploadURL) else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (respData, _) = try await URLSession.shared.upload(for: req, from: data)
        struct UploadResp: Decodable { let storageId: String }
        return try? JSONDecoder().decode(UploadResp.self, from: respData).storageId
    }
```
> `imageId` is only added to `foodDict` when present (the `_storage` validator rejects an empty string). `analyzeFood` decodes the action result directly into `AnalyzedFood` (its `Codable` shape matches the action output). `uploadImage` follows Convex's two-step upload (mutation for URL → POST bytes).

- [ ] **Step 2: Build** — `cd Haven && xcodegen generate && cd .. && xcodebuild ... build` → SUCCEEDED.
  - If `client.mutation("files:generateUploadUrl", with: [:])` is ambiguous (empty dict), use `with: [String: ConvexEncodable?]()`.
  - If `action` can't infer `AnalyzedFood`, annotate as shown (`let result: AnalyzedFood = ...`).
  - Report any other compile error verbatim; do not change the verified API.
- [ ] **Step 3: Guard** → pass.
- [ ] **Step 4: Commit** — `git add Haven/Sources/Services/ConvexService.swift && git commit -m "feat: implement logging writes, analyzeFood, and image upload in ConvexService"`

---

## Task 5: MigraineSheet

**Files:**
- Create: `Haven/Sources/Today/Loggers/MigraineSheet.swift`

- [ ] **Step 1: Write `MigraineSheet.swift`**

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct MigraineSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let existing: Migraine?
    let onSave: (Migraine) async -> Void
    let onRemove: () async -> Void

    @State private var severity: String
    @State private var notes: String

    init(existing: Migraine?, onSave: @escaping (Migraine) async -> Void, onRemove: @escaping () async -> Void) {
        self.existing = existing; self.onSave = onSave; self.onRemove = onRemove
        _severity = State(initialValue: existing?.severity.isEmpty == false ? existing!.severity : "Moderate")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                SheetHeader(title: "Log a migraine", subtitle: "How is it right now?")
                Text("SEVERITY").havenText(.eyebrow, color: theme.inkFaint)
                Segmented(options: ["Mild", "Moderate", "Severe"], selection: $severity)
                Text("NOTES").havenText(.eyebrow, color: theme.inkFaint)
                TextEditor(text: $notes)
                    .frame(height: 100).scrollContentBackground(.hidden)
                    .padding(Spacing.s3).background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    .havenText(.body, color: theme.ink)
                Button {
                    Task { await onSave(Migraine(had: true, severity: severity, time: TodayStore.nowHM(), notes: notes)); dismiss() }
                } label: {
                    Text("Save").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                .accessibilityIdentifier("migraine-save")
                if existing?.had == true {
                    Button { Task { await onRemove(); dismiss() } } label: {
                        Text("Remove migraine").havenText(.meta, color: theme.factorHigh)
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
                    }
                }
                Spacer()
            }
            .padding(Spacing.s6)
        }
    }
}
```

- [ ] **Step 2: Build** → SUCCEEDED. **Guard** → pass.
- [ ] **Step 3: Commit** — `git add Haven/Sources/Today/Loggers/MigraineSheet.swift && git commit -m "feat: add MigraineSheet logger"`

---

## Task 6: SymptomSheet

**Files:**
- Create: `Haven/Sources/Today/Loggers/SymptomSheet.swift`

- [ ] **Step 1: Write `SymptomSheet.swift`** (6 toggle buttons in a 2-col grid)

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct SymptomOption: Identifiable { let id: String; let label: String; let icon: String }

struct SymptomSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let existing: [String]
    let onSave: ([String]) async -> Void

    static let catalog: [SymptomOption] = [
        .init(id: "light", label: "Light / glare", icon: "sun.max"),
        .init(id: "eye", label: "Eye strain", icon: "eye"),
        .init(id: "neck", label: "Neck pain", icon: "figure.stand"),
        .init(id: "back", label: "Back pain", icon: "figure.walk"),
        .init(id: "nausea", label: "Nausea", icon: "exclamationmark.bubble"),
        .init(id: "sound", label: "Sound sensitivity", icon: "speaker.wave.2"),
    ]

    @State private var selected: Set<String>
    init(existing: [String], onSave: @escaping ([String]) async -> Void) {
        self.existing = existing; self.onSave = onSave
        _selected = State(initialValue: Set(existing))
    }

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                SheetHeader(title: "Log symptoms", subtitle: "Tap all that apply")
                LazyVGrid(columns: cols, spacing: Spacing.s3) {
                    ForEach(Self.catalog) { opt in
                        let on = selected.contains(opt.id)
                        Button {
                            if on { selected.remove(opt.id) } else { selected.insert(opt.id) }
                        } label: {
                            HStack(spacing: Spacing.s2) {
                                Image(systemName: opt.icon)
                                Text(opt.label).havenText(.meta, color: on ? theme.ctaInk : theme.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.s4)
                            .background(on ? theme.ctaBg : theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                            .foregroundStyle(on ? theme.ctaInk : theme.inkSoft)
                        }
                    }
                }
                Button {
                    Task { await onSave(Array(selected)); dismiss() }
                } label: {
                    Text("Save").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                .accessibilityIdentifier("symptoms-save")
                Spacer()
            }
            .padding(Spacing.s6)
        }
    }
}
```

- [ ] **Step 2: Build** → SUCCEEDED. **Guard** → pass.
- [ ] **Step 3: Commit** — `git add Haven/Sources/Today/Loggers/SymptomSheet.swift && git commit -m "feat: add SymptomSheet logger"`

---

## Task 7: FactorsSheet (replaces M1 FactorEditor)

**Files:**
- Create: `Haven/Sources/Today/Loggers/FactorsSheet.swift`
- Modify: `Haven/Sources/Today/FactorRings.swift` (remove the `FactorEditor` struct)

- [ ] **Step 1: Write `FactorsSheet.swift`** (sleep slider + segmented + toggle)

```swift
import SwiftUI
import HavenDesignSystem
import HavenCore

struct FactorsSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let initial: Factors?
    let onSave: (Factors) async -> Void

    @State private var sleep: Double
    @State private var stress: String
    @State private var hydration: String
    @State private var weatherSensitive: Bool

    init(initial: Factors?, onSave: @escaping (Factors) async -> Void) {
        self.initial = initial; self.onSave = onSave
        _sleep = State(initialValue: initial?.sleepHours ?? 7)
        _stress = State(initialValue: (initial?.stress ?? .mid).rawValue.capitalized)
        _hydration = State(initialValue: (initial?.hydration ?? .mid).rawValue.capitalized)
        _weatherSensitive = State(initialValue: initial?.weatherSensitive ?? false)
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.s5) {
                SheetHeader(title: "Daily factors", subtitle: "Often more predictive than food alone.")
                HStack {
                    Text("SLEEP").havenText(.eyebrow, color: theme.inkFaint)
                    Spacer()
                    Text(String(format: "%.1fh", sleep)).havenText(.meta, color: theme.ink)
                }
                Slider(value: $sleep, in: 0...12, step: 0.5).tint(theme.accent)
                Text("STRESS").havenText(.eyebrow, color: theme.inkFaint)
                Segmented(options: ["Low", "Mid", "High"], selection: $stress)
                Text("HYDRATION").havenText(.eyebrow, color: theme.inkFaint)
                Segmented(options: ["Low", "Mid", "High"], selection: $hydration)
                Toggle(isOn: $weatherSensitive) {
                    Text("I felt weather-sensitive today").havenText(.body, color: theme.inkSoft)
                }.tint(theme.accent)
                Button {
                    Task {
                        await onSave(Factors(sleepHours: sleep, stress: level(stress),
                                             hydration: level(hydration), weatherSensitive: weatherSensitive))
                        dismiss()
                    }
                } label: {
                    Text("Save").havenText(.sectionHead, color: theme.ctaInk)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
                }
                .accessibilityIdentifier("factors-save")
                Spacer()
            }
            .padding(Spacing.s6)
        }
    }

    private func level(_ s: String) -> Level {
        switch s.lowercased() { case "low": .low; case "high": .high; default: .mid }
    }
}
```

- [ ] **Step 2: Edit `FactorRings.swift`** — DELETE the entire `struct FactorEditor: View { ... }` (the whole struct). Keep `FactorRings`. (TodayScreen will be repointed to `FactorsSheet` in Task 10.)

- [ ] **Step 3: Build** — will FAIL to compile because `TodayScreen.swift` still references `FactorEditor`. That's expected; it's repointed in Task 10. To keep this task's build green in isolation, temporarily point TodayScreen's sheet at `FactorsSheet` now:

In `TodayScreen.swift`, change the factor sheet presentation from `FactorEditor(initial:onSave:)` to `FactorsSheet(initial:onSave:)` (same signature). Then build → SUCCEEDED.

- [ ] **Step 4: Guard** → pass. **Commit**

```bash
git add Haven/Sources/Today/Loggers/FactorsSheet.swift Haven/Sources/Today/FactorRings.swift Haven/Sources/Today/TodayScreen.swift
git commit -m "feat: add polished FactorsSheet, replace M1 FactorEditor"
```

---

## Task 8: FoodCaptureSheet (two-tier analyze)

**Files:**
- Create: `Haven/Sources/Today/Loggers/FoodCaptureSheet.swift`

- [ ] **Step 1: Write `FoodCaptureSheet.swift`** (describe + photo modes; Analyze → result → Save)

```swift
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
```
> `onSave(food, imageData)` hands both the entry and the raw image bytes to the parent, which uploads the photo (via `ConvexService.uploadImage`) and sets `imageId` before calling `addFood` — keeping the upload orchestration in one place (Task 10).

- [ ] **Step 2: Build** → SUCCEEDED. **Guard** → pass.
- [ ] **Step 3: Commit** — `git add Haven/Sources/Today/Loggers/FoodCaptureSheet.swift && git commit -m "feat: add FoodCaptureSheet with two-tier analyze"`

---

## Task 9: SpeedDial

**Files:**
- Create: `Haven/Sources/Today/Loggers/SpeedDial.swift`

- [ ] **Step 1: Write `SpeedDial.swift`**

```swift
import SwiftUI
import HavenDesignSystem

enum LoggerKind: String, Identifiable { case food, migraine, symptom, factors; var id: String { rawValue } }

struct SpeedDial: View {
    @Environment(\.theme) private var theme
    @Binding var isOpen: Bool
    let onPick: (LoggerKind) -> Void

    private let items: [(LoggerKind, String, String)] = [
        (.food, "Food", "camera"),
        (.migraine, "Migraine", "bolt.heart"),
        (.symptom, "Symptom", "eye"),
        (.factors, "Daily factors", "moon"),
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isOpen {
                Color.black.opacity(0.001).ignoresSafeArea().onTapGesture { isOpen = false }
            }
            VStack(alignment: .trailing, spacing: Spacing.s3) {
                if isOpen {
                    ForEach(items, id: \.0.id) { kind, label, icon in
                        Button { isOpen = false; onPick(kind) } label: {
                            HStack(spacing: Spacing.s2) {
                                Text(label).havenText(.meta, color: theme.ink)
                                Image(systemName: icon).foregroundStyle(theme.accent)
                            }
                            .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s3)
                            .background(theme.surface, in: Capsule())
                        }
                        .accessibilityIdentifier("dial-\(kind.rawValue)")
                    }
                }
                Button { isOpen.toggle() } label: {
                    Image(systemName: "plus").rotationEffect(.degrees(isOpen ? 45 : 0))
                        .foregroundStyle(theme.ctaInk).font(.title2)
                        .frame(width: 56, height: 56).background(theme.ctaBg, in: Circle())
                }
                .accessibilityIdentifier("speed-dial")
            }
        }
    }
}
```
> `.font(.title2)` is an SF Symbol size, not `.font(.system(...))` — the guard targets `.font(.system`, so this passes; the icon glyph is not design-system typography. (If the guard flags it, wrap with `.imageScale(.large)` instead.)

- [ ] **Step 2: Build** → SUCCEEDED. **Guard** → pass (confirm; adjust per the note if needed).
- [ ] **Step 3: Commit** — `git add Haven/Sources/Today/Loggers/SpeedDial.swift && git commit -m "feat: add center speed-dial logger launcher"`

---

## Task 10: Wire everything into `TodayScreen`

**Files:**
- Modify: `Haven/Sources/Today/TodayScreen.swift`

- [ ] **Step 1: Edit `TodayScreen.swift`** — add sheet state + the speed-dial + wire the action buttons. Replace the body's `.overlay`/`.sheet` region and add an enum-driven sheet:

Add state:
```swift
    @State private var activeSheet: LoggerKind?
    @State private var dialOpen = false
```
Replace the bottom-trailing overlay (the dev theme toggle) with the speed-dial (keep the theme toggle as a smaller secondary control if desired, or drop it — minor):
```swift
            .overlay(alignment: .bottomTrailing) {
                SpeedDial(isOpen: $dialOpen) { kind in activeSheet = kind }
                    .padding(Spacing.s6)
            }
```
Replace the single factor `.sheet` with an item-driven sheet covering all loggers:
```swift
        .task { store.start() }
        .sheet(item: $activeSheet) { kind in
            sheet(for: kind).environment(\.theme, theme)
        }
```
Add the builder + the food save orchestration (uploads the photo, then addFood):
```swift
    @ViewBuilder private func sheet(for kind: LoggerKind) -> some View {
        switch kind {
        case .migraine:
            MigraineSheet(existing: store.day?.migraine,
                          onSave: { try? await store.saveMigraine($0) },
                          onRemove: { try? await store.removeMigraine() })
        case .symptom:
            SymptomSheet(existing: store.day?.symptoms ?? []) { try? await store.saveSymptoms($0) }
        case .factors:
            FactorsSheet(initial: store.day?.factors) { try? await store.saveFactors($0) }
        case .food:
            FoodCaptureSheet(analyze: { await store.analyze($0) }) { food, imageData in
                await saveFood(food, imageData)
            }
        }
    }

    private func saveFood(_ food: FoodEntry, _ imageData: Data?) async {
        var entry = food
        if let imageData, let service = store.source as? ConvexService,
           let id = try? await service.uploadImage(imageData) {
            entry = FoodEntry(name: food.name, time: food.time, triggers: food.triggers, note: food.note, imageId: id)
        }
        try? await store.saveFood(entry)
    }
```
Repoint `FactorRings`' tap to open the factors sheet:
```swift
                    FactorRings(factors: store.day?.factors) { activeSheet = .factors }
```
Wire the action buttons — change `ActionButtons()` to accept handlers (see Step 2) and pass:
```swift
                    ActionButtons(onLogMigraine: { activeSheet = .migraine }, onSnapMeal: { activeSheet = .food })
```

> `store.source` must be exposed for the food upload. Add `public let source: DayDataSource` accessor: in `TodayStore`, change `private let source` to `public let source` (the upload needs the concrete `ConvexService`). This is a deliberate, minimal exposure.

- [ ] **Step 2: Update `ActionButtons.swift`** to take handlers:

```swift
struct ActionButtons: View {
    @Environment(\.theme) private var theme
    let onLogMigraine: () -> Void
    let onSnapMeal: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s4) {
            primary("Log a migraine", icon: "bolt.heart", action: onLogMigraine)
            ghost("Snap a meal", icon: "camera", action: onSnapMeal)
        }
    }
    private func primary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).havenText(.sectionHead, color: theme.ctaInk)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.ctaBg, in: RoundedRectangle(cornerRadius: Radius.lg))
        }
        .accessibilityIdentifier("log-migraine")
    }
    private func ghost(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).havenText(.sectionHead, color: theme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(theme.hairline, lineWidth: 1))
        }
        .accessibilityIdentifier("snap-meal")
    }
}
```

- [ ] **Step 3: Change `TodayStore.source` to `public let`** in `HavenCore/Sources/HavenCore/TodayStore.swift` (so TodayScreen can reach `ConvexService.uploadImage`). Re-run `swift test --package-path HavenCore` → still PASS.

- [ ] **Step 4: Build** — `cd Haven && xcodegen generate && cd .. && xcodebuild ... build` → SUCCEEDED. **Guard** → pass.
- [ ] **Step 5: Commit**

```bash
git add Haven/Sources/Today/TodayScreen.swift Haven/Sources/Today/ActionButtons.swift HavenCore/Sources/HavenCore/TodayStore.swift
git commit -m "feat: wire loggers, speed-dial, and action buttons into Today"
```

---

## Task 11: Maestro verification

**Files:**
- Create: `Haven/maestro/loggers.yaml`

- [ ] **Step 1: Ensure seeded data + build/install/launch** on the booted simulator (reuse the P3-T14 sequence: `npx convex dev --once` to deploy M2 functions if not already; `npx convex run seed:seed '{"userId":"sim-device","today":"2026-06-14"}'`; xcodebuild install + launch).

- [ ] **Step 2: Write `Haven/maestro/loggers.yaml`**

```yaml
appId: app.haven.Haven
---
- launchApp
- assertVisible: "Today"
# Open the speed-dial and log a symptom.
- tapOn:
    id: "speed-dial"
- tapOn:
    id: "dial-symptom"
- assertVisible: "Log symptoms"
- tapOn: "Nausea"
- tapOn:
    id: "symptoms-save"
- assertVisible: "Today"
# Log food via describe → analyze (on-device fallback) → save.
- tapOn:
    id: "speed-dial"
- tapOn:
    id: "dial-food"
- assertVisible: "Log food"
- tapOn: "Describe what you ate or drank…"
- inputText: "aged cheddar toastie"
- tapOn:
    id: "food-analyze"
- assertVisible: "Aged cheese"
- tapOn:
    id: "food-save"
- assertVisible: "Logged today"
- takeScreenshot: m2-loggers
```

- [ ] **Step 3: Run** — `export PATH="$PATH:$HOME/.maestro/bin" && maestro test Haven/maestro/loggers.yaml` → all steps COMPLETED, exit 0. Read `m2-loggers.png` to confirm the new food entry ("Aged cheese" trigger) appears in the ledger.

- [ ] **Step 4: Verify the write hit Convex** — `npx convex run days:getDay '{"userId":"sim-device","date":"2026-06-14"}'` shows the new food + symptoms.

- [ ] **Step 5: Commit** — `git add Haven/maestro/loggers.yaml && git commit -m "test: add Maestro flow for M2 loggers"`

---

## Definition of done (M2-P2 = M2 complete)
1. From Today, the speed-dial + action buttons open all four loggers; each saves and the ledger updates reactively (Maestro-verified).
2. Food: describe → Analyze → trigger list → Save → ledger row with trigger chips (on-device engine works with no API key; Claude used when `ANTHROPIC_API_KEY` set).
3. All suites green (Convex, HavenCore, HavenDesignSystem); token guard clean; app builds + runs.

---

## Self-review notes
- **Spec coverage (§7):** Segmented/LevelDot/SheetHeader (T2–T3), ConvexService new methods + analyzeFood + upload (T4), the four sheets (T5–T8), speed-dial (T9), TodayScreen wiring + action buttons (T10), Maestro (T11). FactorEditor→FactorsSheet replacement (T7). store.source exposure for upload (T10).
- **Type consistency:** sheets call `store.save*`/`analyze` (defined M2-P1); `Segmented` uses string options with "Low/Mid/High" mapped to `Level` in FactorsSheet; `LoggerKind` drives both speed-dial and the `.sheet(item:)`; `AnalyzedFood`/`FoodEntry`/`Migraine` shapes match M2-P1.
- **Risks:** (1) convex-swift `action` decode into `AnalyzedFood` — verified shape; fallback documented (T1/T4). (2) `store.source as? ConvexService` cast for upload — works because RootView injects ConvexService; in tests the fake isn't a ConvexService so upload is skipped (nil imageId), which is fine. (3) PhotosPicker can't be driven in Maestro/CI — the flow uses describe mode; photo path is manual-only. (4) guard on `.font(.title2)` in SpeedDial — note + fallback included.
