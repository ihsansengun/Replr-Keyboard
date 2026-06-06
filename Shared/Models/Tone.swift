import Foundation

struct Tone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instruction: String      // the LLM prompt (not shown to the user)
    var blurb: String            // concise, human-readable line shown in Settings → Tones
    var isPreset: Bool
    var isEnabled: Bool

    // Custom decode so old saved tones (missing isEnabled / blurb keys) migrate cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        instruction = try c.decode(String.self, forKey: .instruction)
        blurb       = try c.decodeIfPresent(String.self, forKey: .blurb) ?? ""
        isPreset    = try c.decode(Bool.self,   forKey: .isPreset)
        isEnabled   = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    init(id: UUID, name: String, instruction: String, blurb: String = "", isPreset: Bool, isEnabled: Bool = true) {
        self.id          = id
        self.name        = name
        self.instruction = instruction
        self.blurb       = blurb
        self.isPreset    = isPreset
        self.isEnabled   = isEnabled
    }

    // MARK: - Mode availability

    /// Tone names that can appear in the CHAT keyboard row.
    /// Custom tones (isPreset: false) are always available in both modes.
    static let chatToneNames: Set<String> = [
        "Friendly", "Casual", "Playful", "Witty", "Joker", "Flirty",
        "Seductive", "Empathetic", "Confident", "Direct", "Natural",
        // Hidden-by-default chat tones (user can enable in Settings → Tones):
        "Sarcastic", "Passive Aggressive", "Gen Z",
    ]

    /// Tone names that can appear in the EMAIL keyboard row.
    static let emailToneNames: Set<String> = [
        "Warm Professional", "Professional", "Confident", "Diplomatic",
        "Empathetic", "Assertive", "Enthusiastic", "Concise",
        // Hidden-by-default email tones (user can enable in Settings → Tones):
        "Formal", "Direct", "Friendly",
    ]

    /// Whether this tone is available for the chat keyboard row.
    var availableInChat: Bool {
        !isPreset || Tone.chatToneNames.contains(name)
    }

    /// Whether this tone is available for the email keyboard row.
    var availableInEmail: Bool {
        !isPreset || Tone.emailToneNames.contains(name)
    }

    // MARK: - Presets

    // `blurb` is the concise line shown in Settings; `instruction` is the LLM prompt.
    // Chat tones are listed in their default keyboard-row order — Natural leads as the
    // clean default, then the set runs dating-forward. Users can drag to reorder any of
    // these in Settings → Tones (the order persists and drives the keyboard row).
    // Tones with isEnabled: false are hidden by default and can be enabled there.
    static let presets: [Tone] = [

        // ── Chat tones — default keyboard-row order ──────────────────────────

        Tone(id: UUID(), name: "Natural",
             instruction: "A clean, natural reply — well-written and human, no special personality.",
             blurb: "Clean, well-written replies with no added personality — just reads the room.",
             isPreset: true),

        Tone(id: UUID(), name: "Friendly",
             instruction: "Open with something personal from the chat. Warm but grounded — no exclamation marks after every sentence. Make them feel seen, not managed.",
             blurb: "Warm and personal, without trying too hard.",
             isPreset: true),

        Tone(id: UUID(), name: "Casual",
             instruction: "Text like a close friend. Contractions, fragments, and shorthand are all fine. Match their spelling and punctuation style exactly. Never be more polished than they are.",
             blurb: "Texts like a close friend — relaxed, unpolished, real.",
             isPreset: true),

        Tone(id: UUID(), name: "Playful",
             instruction: "Be light and a little teasing — the kind of reply that makes them smile without trying too hard. Keep it breezy. A touch of mischief is welcome; don't commit to a full bit. Make the conversation feel effortless and fun to be in.",
             blurb: "Light and a little teasing — makes them smile.",
             isPreset: true),

        Tone(id: UUID(), name: "Flirty",
             instruction: "Show romantic interest without showing all your cards. Slightly unpredictable — don't give them exactly what they expect. Tease without explaining it. One question that shows you were paying attention. Playful tension over obvious enthusiasm.",
             blurb: "Shows romantic interest while keeping a little mystery.",
             isPreset: true),

        Tone(id: UUID(), name: "Witty",
             instruction: "Find the unexpected angle. Understatement over enthusiasm. One dry observation beats three forced jokes. Never explain the wit.",
             blurb: "Dry and clever — finds the unexpected angle.",
             isPreset: true),

        Tone(id: UUID(), name: "Joker",
             instruction: "Find the joke in whatever they said. Puns if they land naturally, absurdist takes, unexpected callbacks — commit to the bit. If there's no obvious angle, make the mundane ridiculous. Never explain the joke.",
             blurb: "Goes for the laugh — puns and playful absurdity.",
             isPreset: true),

        Tone(id: UUID(), name: "Confident",
             instruction: "Reply from a place of self-assurance — like someone who has options but finds this conversation worth their time. Don't over-explain or qualify. Grounded and brief beats long and eager. Leave them a little curious, not fully satisfied.",
             blurb: "Self-assured and unbothered — never over-eager.",
             isPreset: true),

        Tone(id: UUID(), name: "Seductive",
             instruction: "Suggestive and explicitly sensual. Take whatever they said and turn the heat up. Bold, specific, no euphemisms. Make the reply impossible to ignore.",
             blurb: "Suggestive and sensual — turns up the heat.",
             isPreset: true),

        Tone(id: UUID(), name: "Empathetic",
             instruction: "Acknowledge what they're feeling before addressing content. Reflect their emotion back in your own words first. Don't jump to solutions.",
             blurb: "Warm and understanding — leads with how they feel.",
             isPreset: true),

        Tone(id: UUID(), name: "Direct",
             instruction: "Lead with the answer. One sentence when possible, two at most. Cut the closing line — it's usually filler.",
             blurb: "Straight to the point. No filler.",
             isPreset: true),

        // ── Email tones — visible in the email keyboard row ───────────────────

        Tone(id: UUID(), name: "Warm Professional",
             instruction: "Write like a trusted colleague, not a corporate auto-reply. Professional structure — clear point, brief support — but with genuine warmth. Make them feel like a person, not a ticket number. Close with something specific to the situation.",
             blurb: "Polished but personable — a trusted colleague, not a corporate reply.",
             isPreset: true),

        Tone(id: UUID(), name: "Professional",
             instruction: "No contractions. State your point first, support it second. Close with a clear next step. No idioms or slang.",
             blurb: "Clear and businesslike — structured and to the point.",
             isPreset: true),

        Tone(id: UUID(), name: "Diplomatic",
             instruction: "Acknowledge their position before presenting yours. Never dismiss the concern, even if you disagree. Find common ground first, then navigate toward your point. Preserve the relationship while holding your position. End on something constructive.",
             blurb: "Tactful — pushes back or declines without burning bridges.",
             isPreset: true),

        Tone(id: UUID(), name: "Assertive",
             instruction: "State your position clearly and without apology. No hedging, no excessive qualifiers. Explain your reasoning briefly — once. Don't over-justify. Firm but not aggressive. End with a clear next step or expectation.",
             blurb: "Firm and clear about your position — without aggression.",
             isPreset: true),

        Tone(id: UUID(), name: "Enthusiastic",
             instruction: "Match and slightly amplify their energy. Lead with what genuinely excites you about what they said. One well-placed exclamation mark, not three.",
             blurb: "Upbeat and energetic — matches their excitement.",
             isPreset: true),

        Tone(id: UUID(), name: "Concise",
             instruction: "Two sentences maximum. If you've written three, delete one. Every word must earn its place.",
             blurb: "Short and sharp — every word earns its place.",
             isPreset: true),

        // ── Hidden by default — enable in Settings → Tones ────────────────────

        Tone(id: UUID(), name: "Sarcastic",
             instruction: "Deadpan and magnificently condescending. Respond with exaggerated sincerity — the more obvious their point, the more impressed you seem. Celebrate mediocrity as if it's genius. Short, punchy delivery. Never break the facade. Never explain it.",
             blurb: "Deadpan and dryly condescending — straight-faced throughout.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Passive Aggressive",
             instruction: "Agree with everything but make it slightly sting. Use 'no worries' and 'totally fine' liberally. End with something that sounds supportive but clearly isn't. Never be openly rude — the vibe does the work.",
             blurb: "Agreeable on the surface, with a little sting underneath.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Gen Z",
             instruction: "Lowercase everything. Use 'no cap', 'lowkey', 'it's giving', 'not me', 'slay' sparingly — only when they'd actually land. Never try too hard. One emoji max, only if it adds something. Vibes over grammar.",
             blurb: "Lowercase, low-effort cool — internet slang, used sparingly.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Formal",
             instruction: "Full words only — no contractions or abbreviations. State your purpose in the first sentence. Complete sentences, clean close.",
             blurb: "No contractions, complete sentences — buttoned-up and correct.",
             isPreset: true, isEnabled: false),
    ]
}
