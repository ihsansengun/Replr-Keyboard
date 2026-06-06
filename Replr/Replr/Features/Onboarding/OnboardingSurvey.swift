import Foundation

/// The onboarding personalization survey: a pure mapping from the user's pick to a seeded
/// starting tone + About You hint, plus a side-effecting `apply` that persists it.
/// `seed(for:)` is pure and unit-tested; `apply` wraps it with persistence.
enum OnboardingSurvey {
    struct Option: Identifiable, Equatable {
        let id: String
        let label: String
        let icon: String       // SF Symbol
        let toneName: String   // must match a Tone.presets name (verified by tests)
        let aboutHint: String  // appended to About You; "" = none
    }

    static let options: [Option] = [
        Option(id: "dating",  label: "Dating apps",         icon: "heart.fill",     toneName: "Flirty",       aboutHint: "I'm replying on dating apps."),
        Option(id: "friends", label: "Texting friends",     icon: "message.fill",   toneName: "Casual",       aboutHint: "I'm texting friends."),
        Option(id: "work",    label: "Work & Slack",        icon: "briefcase.fill", toneName: "Professional", aboutHint: "I'm messaging coworkers."),
        Option(id: "family",  label: "Family",              icon: "house.fill",     toneName: "Friendly",     aboutHint: "I'm messaging family."),
        Option(id: "email",   label: "Email",               icon: "envelope.fill",  toneName: "Professional", aboutHint: "I'm drafting emails."),
        Option(id: "other",   label: "A bit of everything", icon: "sparkles",       toneName: "Natural",      aboutHint: ""),
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

    /// Persists the seed: selects the matching tone and appends the hint to About You
    /// (never overwrites an existing About You).
    static func apply(_ selectedIDs: [String], service: AppGroupService = .shared) {
        let s = seed(for: selectedIDs)
        if let tone = service.readTones().first(where: { $0.name == s.toneName }) {
            service.saveSelectedTone(tone)
        }
        guard !s.aboutHint.isEmpty else { return }
        let existing = service.aboutUser.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty {
            service.aboutUser = s.aboutHint
        } else if !existing.localizedCaseInsensitiveContains(s.aboutHint) {
            service.aboutUser = existing + " " + s.aboutHint
        }
    }
}
