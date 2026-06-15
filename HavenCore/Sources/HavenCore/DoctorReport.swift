import Foundation

/// Plain-text migraine summary for the share-sheet export stub.
public enum DoctorReport {
    public static func text(days: [DayLog], klass: String) -> String {
        let sorted = days.sorted { $0.date < $1.date }
        let attacks = sorted.filter { $0.migraine?.had == true }
        let range = sorted.isEmpty ? "no logged days"
            : "\(sorted.first!.date) to \(sorted.last!.date)"
        var lines = [
            "Haven migraine summary",
            klass,
            "Range: \(range)",
            "\(attacks.count) migraine day(s) recorded",
            "",
        ]
        for d in attacks {
            let sev = d.migraine?.severity ?? "unknown"
            let sym = d.symptoms.isEmpty ? "" : " — \(d.symptoms.joined(separator: ", "))"
            lines.append("\(d.date): \(sev)\(sym)")
        }
        return lines.joined(separator: "\n")
    }
}
