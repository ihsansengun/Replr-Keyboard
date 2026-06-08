import Foundation

/// The onboarding personalization survey: maps the user's communication-style pick to a
/// seeded tone + a concise About You hint that ships with every LLM call.
/// `seed(for:)` is pure and unit-tested; `apply` wraps it with persistence.
enum OnboardingSurvey {
    struct Option: Identifiable, Equatable {
        let id: String
        let label: String
        let icon: String       // SF Symbol
        let toneName: String   // must match a Tone.presets name (verified by tests)
        let aboutHint: String  // written to About You when user hasn't typed their own
    }

    /// Four style-based options (replaces the old platform-based list).
    /// These describe *how the user communicates*, not which app they use.
    static let options: [Option] = [
        Option(id: "direct",
               label: "Confident & direct",
               icon: "bolt.fill",
               toneName: "Confident",
               aboutHint: "I tend to be confident and direct."),
        Option(id: "warm",
               label: "Warm & friendly",
               icon: "sun.max.fill",
               toneName: "Friendly",
               aboutHint: "I come across as warm and friendly."),
        Option(id: "witty",
               label: "Witty & playful",
               icon: "face.smiling.fill",
               toneName: "Witty",
               aboutHint: "I tend to be witty and playful."),
        Option(id: "thoughtful",
               label: "Thoughtful & measured",
               icon: "sparkles",
               toneName: "Natural",
               aboutHint: "I tend to be thoughtful and measured."),
    ]

    struct Seed: Equatable {
        let toneName: String
        let aboutHint: String
    }

    /// Maps the ordered selection (first = primary pick) to a tone + About You hint.
    /// Empty / unknown selection → Natural, no hint.
    static func seed(for selectedIDs: [String]) -> Seed {
        guard let primary = selectedIDs.first,
              let opt = options.first(where: { $0.id == primary }) else {
            return Seed(toneName: "Natural", aboutHint: "")
        }
        return Seed(toneName: opt.toneName, aboutHint: opt.aboutHint)
    }

    /// Persists the seed: selects the matching tone and writes the hint to About You
    /// only when About You is currently empty (never overwrites user-typed text).
    static func apply(_ selectedIDs: [String], service: AppGroupService = .shared) {
        let s = seed(for: selectedIDs)
        if let tone = service.readTones().first(where: { $0.name == s.toneName }) {
            service.saveSelectedTone(tone)
        }
        guard !s.aboutHint.isEmpty else { return }
        let existing = service.aboutUser.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty {
            service.aboutUser = s.aboutHint
        }
    }
}
