import Foundation

public struct ProfileRow: Sendable, Equatable, Identifiable {
    public let questionId: String
    public let title: String   // short label for the row
    public let value: String   // joined selected option label(s)
    public var id: String { questionId }
}

/// Short row titles (the onboarding `title` is a full sentence; rows need a label).
private let shortTitles: [String: String] = [
    "frequency": "Frequency", "duration": "Living with them", "age": "Age",
    "sex": "Sex at birth", "cycle": "Cycle", "aura": "Aura",
    "symptoms": "Symptoms", "severity": "Severity", "triggers": "Suspected triggers",
    "meds": "Treatment", "goal": "Goals",
]

/// Builds the editable summary rows from stored answers, in catalog order.
/// Skips unanswered questions and the sex-gated `cycle` row when `sex` isn't female/intersex.
public func profileRows(answers: [String: [String]]) -> [ProfileRow] {
    let sex = answers["sex"]?.first ?? ""
    return OnboardingCatalog.questions.compactMap { q -> ProfileRow? in
        if let req = q.requiresSex, !req.contains(sex) { return nil }
        guard let picked = answers[q.id], !picked.isEmpty else { return nil }
        let allOptions = q.options + (q.notSure.map { [$0] } ?? [])
        let labels = picked.compactMap { v in allOptions.first { $0.value == v }?.label }
        guard !labels.isEmpty else { return nil }
        return ProfileRow(questionId: q.id, title: shortTitles[q.id] ?? q.title, value: labels.joined(separator: ", "))
    }
}
