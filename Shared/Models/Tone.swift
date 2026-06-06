import Foundation

struct Tone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instruction: String
    var isPreset: Bool
    var isEnabled: Bool

    // Custom decode so old saved tones (no isEnabled key) migrate to isEnabled = true
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        instruction = try c.decode(String.self, forKey: .instruction)
        isPreset    = try c.decode(Bool.self,   forKey: .isPreset)
        isEnabled   = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    init(id: UUID, name: String, instruction: String, isPreset: Bool, isEnabled: Bool = true) {
        self.id          = id
        self.name        = name
        self.instruction = instruction
        self.isPreset    = isPreset
        self.isEnabled   = isEnabled
    }

    // Each tone maps to a distinct human emotional state — not a style label.
    // Tones visible in the keyboard row are ordered for Replr's social/dating-first purpose.
    // Tones with isEnabled: false are available in Settings → Tones but hidden by default.
    static let presets: [Tone] = [

        // ── Default visible tones (shown in keyboard row, left → right) ──────

        Tone(id: UUID(), name: "Friendly",
             instruction: "Open with something personal from the chat. Warm but grounded — no exclamation marks after every sentence. Make them feel seen, not managed.",
             isPreset: true),

        Tone(id: UUID(), name: "Casual",
             instruction: "Text like a close friend. Contractions, fragments, and shorthand are all fine. Match their spelling and punctuation style exactly. Never be more polished than they are.",
             isPreset: true),

        Tone(id: UUID(), name: "Playful",
             instruction: "Be light and a little teasing — the kind of reply that makes them smile without trying too hard. Keep it breezy. A touch of mischief is welcome; don't commit to a full bit. Make the conversation feel effortless and fun to be in.",
             isPreset: true),

        Tone(id: UUID(), name: "Witty",
             instruction: "Find the unexpected angle. Understatement over enthusiasm. One dry observation beats three forced jokes. Never explain the wit.",
             isPreset: true),

        Tone(id: UUID(), name: "Joker",
             instruction: "Find the joke in whatever they said. Puns if they land naturally, absurdist takes, unexpected callbacks — commit to the bit. If there's no obvious angle, make the mundane ridiculous. Never explain the joke.",
             isPreset: true),

        Tone(id: UUID(), name: "Flirty",
             instruction: "Show romantic interest without showing all your cards. Slightly unpredictable — don't give them exactly what they expect. Tease without explaining it. One question that shows you were paying attention. Playful tension over obvious enthusiasm.",
             isPreset: true),

        Tone(id: UUID(), name: "Seductive",
             instruction: "Suggestive and explicitly sensual. Take whatever they said and turn the heat up. Bold, specific, no euphemisms. Make the reply impossible to ignore.",
             isPreset: true),

        Tone(id: UUID(), name: "Empathetic",
             instruction: "Acknowledge what they're feeling before addressing content. Reflect their emotion back in your own words first. Don't jump to solutions.",
             isPreset: true),

        Tone(id: UUID(), name: "Confident",
             instruction: "Reply from a place of self-assurance — like someone who has options but finds this conversation worth their time. Don't over-explain or qualify. Grounded and brief beats long and eager. Leave them a little curious, not fully satisfied.",
             isPreset: true),

        Tone(id: UUID(), name: "Direct",
             instruction: "Lead with the answer. One sentence when possible, two at most. Cut the closing line — it's usually filler.",
             isPreset: true),

        // Natural sits at the end of the row — a "reset" to clean, personality-free replies.
        // It is also the default selected tone for new users (see readSelectedTone).
        Tone(id: UUID(), name: "Natural",
             instruction: "A clean, natural reply — well-written and human, no special personality.",
             isPreset: true),

        // ── Hidden by default (available in Settings → Tones) ─────────────────

        Tone(id: UUID(), name: "Sarcastic",
             instruction: "Deadpan and magnificently condescending. Respond with exaggerated sincerity — the more obvious their point, the more impressed you seem. Celebrate mediocrity as if it's genius. Short, punchy delivery. Never break the facade. Never explain it.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Passive Aggressive",
             instruction: "Agree with everything but make it slightly sting. Use 'no worries' and 'totally fine' liberally. End with something that sounds supportive but clearly isn't. Never be openly rude — the vibe does the work.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Gen Z",
             instruction: "Lowercase everything. Use 'no cap', 'lowkey', 'it's giving', 'not me', 'slay' sparingly — only when they'd actually land. Never try too hard. One emoji max, only if it adds something. Vibes over grammar.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Enthusiastic",
             instruction: "Match and slightly amplify their energy. Lead with what genuinely excites you about what they said. One well-placed exclamation mark, not three.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Concise",
             instruction: "Two sentences maximum. If you've written three, delete one. Every word must earn its place.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Professional",
             instruction: "No contractions. State your point first, support it second. Close with a clear next step. No idioms or slang.",
             isPreset: true, isEnabled: false),

        Tone(id: UUID(), name: "Formal",
             instruction: "Full words only — no contractions or abbreviations. State your purpose in the first sentence. Complete sentences, clean close.",
             isPreset: true, isEnabled: false),
    ]
}
