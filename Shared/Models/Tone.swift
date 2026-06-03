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

    // All 10 presets enabled by default. User can hide any from Tones settings.
    static let presets: [Tone] = [
        Tone(id: UUID(), name: "Friendly",     instruction: "Open with something personal from the chat. Warm but grounded — no exclamation marks after every sentence. Make them feel seen, not managed.",                              isPreset: true),
        Tone(id: UUID(), name: "Casual",       instruction: "Text like a close friend. Contractions, fragments, and shorthand are all fine. Match their spelling and punctuation style exactly. Never be more polished than they are.", isPreset: true),
        Tone(id: UUID(), name: "Direct",       instruction: "Lead with the answer. One sentence when possible, two at most. Cut the closing line — it's usually filler.",                                                              isPreset: true),
        Tone(id: UUID(), name: "Witty",        instruction: "Find the unexpected angle. Understatement over enthusiasm. One dry observation beats three forced jokes. Never explain the wit.",                                          isPreset: true),
        Tone(id: UUID(), name: "Professional", instruction: "No contractions. State your point first, support it second. Close with a clear next step. No idioms or slang.",                                                          isPreset: true),
        Tone(id: UUID(), name: "Empathetic",   instruction: "Acknowledge what they're feeling before addressing content. Reflect their emotion back in your own words first. Don't jump to solutions.",                               isPreset: true),
        Tone(id: UUID(), name: "Enthusiastic", instruction: "Match and slightly amplify their energy. Lead with what genuinely excites you about what they said. One well-placed exclamation mark, not three.",                       isPreset: true),
        Tone(id: UUID(), name: "Concise",      instruction: "Two sentences maximum. If you've written three, delete one. Every word must earn its place.",                                                                             isPreset: true),
        Tone(id: UUID(), name: "Formal",       instruction: "Full words only — no contractions or abbreviations. State your purpose in the first sentence. Complete sentences, clean close.",                                          isPreset: true),
        Tone(id: UUID(), name: "Dating",       instruction: "Be slightly unpredictable — don't give them exactly what they expect. Tease without explaining it. One question that shows you were paying attention. Confident, not eager.", isPreset: true),
        Tone(id: UUID(), name: "Joker",        instruction: "Find the joke in whatever they said. Puns if they land naturally, absurdist takes, unexpected callbacks — commit to the bit. If there's no obvious angle, make the mundane ridiculous. Never explain the joke.",                isPreset: true),
    ]
}
