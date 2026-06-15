import Foundation

public struct OnboardingOption: Sendable, Equatable, Identifiable {
    public let value: String; public let label: String; public let icon: String?
    public var id: String { value }
    public init(_ value: String, _ label: String, icon: String? = nil) { self.value = value; self.label = label; self.icon = icon }
}
public struct OnboardingQuestion: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable { case single, multi }
    public enum Layout: Sendable { case list, grid }
    public let id: String; public let kind: Kind; public let layout: Layout
    public let kicker: String; public let title: String; public let sub: String?
    public let options: [OnboardingOption]
    public let requiresSex: [String]?
    public let notSure: OnboardingOption?
}

public struct Profile: Sendable, Equatable {
    public struct Watch: Sendable, Equatable { public let icon: String; public let title: String; public let sub: String }
    public let klass: String
    public let suspected: [String]
    public let watch: [Watch]
}

public enum OnboardingCatalog {
    public static let questions: [OnboardingQuestion] = [
        .init(id: "frequency", kind: .single, layout: .list, kicker: "About you", title: "How often do migraines hit?", sub: "A rough average is fine — you can refine this later.", options: [
            .init("rare", "Rarely — a few times a year"), .init("1-3mo", "1–3 days a month"), .init("weekly", "Around 1 day a week"), .init("2-3wk", "2–3 days a week"), .init("chronic", "Most days — it's constant")], requiresSex: nil, notSure: nil),
        .init(id: "duration", kind: .single, layout: .list, kicker: "About you", title: "How long have you lived with them?", sub: nil, options: [
            .init("lt1", "Less than a year"), .init("1-3", "1 to 3 years"), .init("3-10", "3 to 10 years"), .init("gt10", "Over 10 years"), .init("always", "As long as I can remember")], requiresSex: nil, notSure: nil),
        .init(id: "age", kind: .single, layout: .list, kicker: "About you", title: "Your age range", sub: "Migraine patterns shift with age, so this helps us calibrate.", options: [
            .init("u18", "Under 18"), .init("18-24", "18 – 24"), .init("25-34", "25 – 34"), .init("35-44", "35 – 44"), .init("45-54", "45 – 54"), .init("55+", "55 or older")], requiresSex: nil, notSure: nil),
        .init(id: "sex", kind: .single, layout: .list, kicker: "About you", title: "Sex assigned at birth", sub: "Hormones are one of the most common drivers, so this matters clinically.", options: [
            .init("female", "Female"), .init("male", "Male"), .init("intersex", "Intersex"), .init("na", "Prefer not to say")], requiresSex: nil, notSure: nil),
        .init(id: "cycle", kind: .single, layout: .list, kicker: "About you", title: "Do you track a menstrual cycle?", sub: "If so, Haven can line up attacks with your cycle to surface hormonal patterns.", options: [
            .init("track", "Yes — I'd like to track it"), .init("have", "I have a cycle, but won't track it"), .init("no", "No, or not applicable")], requiresSex: ["female", "intersex"], notSure: nil),
        .init(id: "aura", kind: .single, layout: .list, kicker: "Your migraines", title: "Do you get aura?", sub: "Aura is warning signs 5–60 min before the pain.", options: [
            .init("often", "Yes, most of the time"), .init("sometimes", "Sometimes"), .init("no", "No, never"), .init("unsure", "I'm not sure")], requiresSex: nil, notSure: nil),
        .init(id: "symptoms", kind: .multi, layout: .grid, kicker: "Your migraines", title: "What comes with them?", sub: "Select everything you tend to feel during an attack.", options: [
            .init("nausea", "Nausea", icon: "cup.and.saucer"), .init("light", "Light sensitivity", icon: "sun.max"), .init("sound", "Sound sensitivity", icon: "speaker.wave.2"), .init("smell", "Smell sensitivity", icon: "wind"), .init("vision", "Vision changes", icon: "eye"), .init("neck", "Neck / shoulder pain", icon: "figure.stand"), .init("dizzy", "Dizziness", icon: "waveform.path.ecg"), .init("throb", "Throbbing pain", icon: "bolt")], requiresSex: nil, notSure: nil),
        .init(id: "severity", kind: .single, layout: .list, kicker: "Your migraines", title: "At their worst, how bad do they get?", sub: "Think about how much they stop your day.", options: [
            .init("push", "I can push through it"), .init("slow", "I have to slow right down"), .init("liedown", "I need to lie down in the dark"), .init("nofunction", "I can't function at all")], requiresSex: nil, notSure: nil),
        .init(id: "triggers", kind: .multi, layout: .grid, kicker: "What you suspect", title: "What do you think sets yours off?", sub: "Pick any you suspect.", options: [
            .init("food", "Certain foods", icon: "fork.knife"), .init("alcohol", "Alcohol", icon: "wineglass"), .init("caffeine", "Caffeine", icon: "cup.and.saucer"), .init("weather", "Weather changes", icon: "cloud"), .init("stress", "Stress", icon: "bolt"), .init("sleep", "Poor sleep", icon: "moon"), .init("dehydration", "Dehydration", icon: "drop"), .init("skipped", "Skipped meals", icon: "takeoutbag.and.cup.and.straw")], requiresSex: nil, notSure: .init("unsure", "I'm honestly not sure yet")),
        .init(id: "meds", kind: .single, layout: .list, kicker: "Treatment", title: "How do you treat them now?", sub: "However you manage today is fine.", options: [
            .init("preventive", "Daily preventive medication"), .init("rescue", "Rescue meds when one hits"), .init("otc", "Over-the-counter only"), .init("supplements", "Supplements or natural remedies"), .init("nothing", "Nothing yet")], requiresSex: nil, notSure: nil),
        .init(id: "goal", kind: .multi, layout: .list, kicker: "Your goal", title: "What would make Haven worth it?", sub: "Pick all that fit.", options: [
            .init("triggers", "Pinpoint my triggers"), .init("fewer", "Have fewer attacks"), .init("doctor", "Prepare for a doctor's visit"), .init("patterns", "Understand my patterns"), .init("record", "Just keep a clear record")], requiresSex: nil, notSure: nil),
    ]
}

public func buildProfile(_ answers: [String: [String]]) -> Profile {
    let freq = answers["frequency"]?.first
    let aura = answers["aura"]?.first
    let auraYes = aura == "often" || aura == "sometimes"
    let chronic = freq == "chronic" || freq == "2-3wk"
    let klass = "\(chronic ? "Chronic" : "Episodic") migraine\(auraYes ? " with aura" : "")"

    let TRIG = ["food": "Food", "alcohol": "Alcohol", "caffeine": "Caffeine", "weather": "Weather",
                "stress": "Stress", "sleep": "Sleep", "dehydration": "Hydration", "skipped": "Meal timing"]
    let picked = (answers["triggers"] ?? []).filter { $0 != "unsure" }.compactMap { TRIG[$0] }
    let suspected = picked.isEmpty ? ["To be discovered"] : picked

    var watch: [Profile.Watch] = [
        .init(icon: "cloud", title: "Barometric weather risk", sub: "flagged before pressure swings"),
        .init(icon: "fork.knife", title: "Meals & drinks", sub: "scanned for common dietary triggers"),
        .init(icon: "moon", title: "Sleep & stress", sub: "tracked as the factors that stack up"),
    ]
    if answers["cycle"]?.first == "track" {
        watch.append(.init(icon: "waveform.path.ecg", title: "Hormonal cycle", sub: "aligned with your attacks"))
    }
    return Profile(klass: klass, suspected: suspected, watch: watch)
}
