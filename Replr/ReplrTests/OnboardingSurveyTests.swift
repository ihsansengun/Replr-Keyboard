import Testing
@testable import Replr

struct OnboardingSurveyTests {

    @Test func emptySelectionSeedsNatural() {
        let s = OnboardingSurvey.seed(for: [])
        #expect(s.toneName == "Natural")
        #expect(s.aboutHint.isEmpty)
    }

    @Test func datingPrimarySeedsFlirty() {
        let s = OnboardingSurvey.seed(for: ["dating", "friends"])
        #expect(s.toneName == "Flirty")
        #expect(s.aboutHint == "I'm replying on dating apps.")
    }

    @Test func primaryPickWinsOverLater() {
        let s = OnboardingSurvey.seed(for: ["work", "dating"])
        #expect(s.toneName == "Professional")
    }

    @Test func unknownIDFallsBackToNatural() {
        let s = OnboardingSurvey.seed(for: ["nope"])
        #expect(s.toneName == "Natural")
        #expect(s.aboutHint.isEmpty)
    }

    /// Guards against a typo'd tone name that wouldn't match a real preset (so seeding silently no-ops).
    @Test func everyOptionMapsToARealPresetTone() {
        let presetNames = Set(Tone.presets.map(\.name))
        for opt in OnboardingSurvey.options {
            #expect(presetNames.contains(opt.toneName), "\(opt.toneName) is not a Tone.presets name")
        }
    }
}
