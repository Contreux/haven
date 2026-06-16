import Foundation

/// One selectable symptom: a stable storage `id`, a human label, and an SF Symbol name.
public struct SymptomInfo: Sendable, Identifiable, Equatable {
    public let id: String
    public let label: String
    public let icon: String
    public init(id: String, label: String, icon: String) {
        self.id = id; self.label = label; self.icon = icon
    }
}

/// The single source of truth for symptom ids → labels (and icons), shared by the
/// symptom logger UI and the ledger so raw ids like "eye" never reach the screen.
public enum SymptomCatalog {
    public static let all: [SymptomInfo] = [
        .init(id: "light",  label: "Light / glare",     icon: "sun.max"),
        .init(id: "eye",    label: "Eye strain",        icon: "eye"),
        .init(id: "neck",   label: "Neck pain",         icon: "figure.stand"),
        .init(id: "back",   label: "Back pain",         icon: "figure.walk"),
        .init(id: "nausea", label: "Nausea",            icon: "exclamationmark.bubble"),
        .init(id: "sound",  label: "Sound sensitivity", icon: "speaker.wave.2"),
    ]

    /// Friendly label for a stored id, falling back to the id itself if unknown.
    public static func label(for id: String) -> String {
        all.first { $0.id == id }?.label ?? id
    }
}
