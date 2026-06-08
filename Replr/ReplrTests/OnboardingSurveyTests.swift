import Testing
@testable import Replr

struct ContactIdentityTests {

    @Test func normalizeStripsTrailingEmojiCaseAndPunctuation() {
        #expect(normalizeContactName("Alex 🌸") == normalizeContactName("alex"))
        #expect(normalizeContactName("  Mom ") == normalizeContactName("mom"))
        #expect(normalizeContactName("Sarah!!") == "sarah")
    }

    @Test func normalizeCollapsesInternalWhitespace() {
        #expect(normalizeContactName("Mary   Jane") == "mary jane")
    }

    @Test func normalizeKeepsDistinctNamesDistinct() {
        #expect(normalizeContactName("Mom") != normalizeContactName("Mum"))
        #expect(normalizeContactName("Alex") != normalizeContactName("Alexa"))
    }
}

struct OnboardingSurveyTests {

    @Test func emptySelectionSeedsNatural() {
        let s = OnboardingSurvey.seed(for: [])
        #expect(s.toneName == "Natural")
        #expect(s.aboutHint.isEmpty)
    }

    @Test func wittyPrimarySeedsWitty() {
        let s = OnboardingSurvey.seed(for: ["witty", "warm"])
        #expect(s.toneName == "Witty")
        #expect(s.aboutHint == "I tend to be witty and playful.")
    }

    @Test func primaryPickWinsOverLater() {
        let s = OnboardingSurvey.seed(for: ["direct", "witty"])
        #expect(s.toneName == "Confident")
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
