import Foundation

/// Onboarding answers are stored as a JSON string of `{questionId: [optionValue]}`.
/// These are the single decode/encode path shared by onboarding and the profile editor.
public func answersDict(from json: String) -> [String: [String]] {
    guard let data = json.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
    else { return [:] }
    return obj
}

public func answersJSON(from dict: [String: [String]]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
          let s = String(data: data, encoding: .utf8) else { return "{}" }
    return s
}
