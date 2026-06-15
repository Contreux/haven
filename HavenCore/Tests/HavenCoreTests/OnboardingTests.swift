import Testing
@testable import HavenCore

@Suite struct OnboardingTests {
    @Test func catalogHasElevenQuestions() {
        #expect(OnboardingCatalog.questions.count == 11)
        #expect(OnboardingCatalog.questions.first?.id == "frequency")
    }
    @Test func cycleQuestionRequiresSex() {
        let cycle = OnboardingCatalog.questions.first { $0.id == "cycle" }!
        #expect(cycle.requiresSex == ["female", "intersex"])
    }
    @Test func buildsEpisodicVsChronic() {
        #expect(buildProfile(["frequency": ["rare"]]).klass == "Episodic migraine")
        #expect(buildProfile(["frequency": ["chronic"]]).klass == "Chronic migraine")
        #expect(buildProfile(["frequency": ["weekly"], "aura": ["often"]]).klass == "Episodic migraine with aura")
    }
    @Test func suspectedChipsMapTriggers() {
        let p = buildProfile(["triggers": ["alcohol", "weather", "unsure"]])
        #expect(p.suspected.contains("Alcohol"))
        #expect(p.suspected.contains("Weather"))
        #expect(p.suspected.contains("To be discovered") == false)  // had real picks
    }
    @Test func emptyTriggersShowDiscovery() {
        #expect(buildProfile([:]).suspected == ["To be discovered"])
    }
    @Test func cycleTrackAddsHormonalWatch() {
        let p = buildProfile(["cycle": ["track"]])
        #expect(p.watch.contains { $0.title == "Hormonal cycle" })
    }
}
