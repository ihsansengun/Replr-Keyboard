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

    // 4 defaults: always on keyboard out of the box.
    // 6 optional: off by default, user enables them in Tones settings.
    static let presets: [Tone] = [
        Tone(id: UUID(), name: "Friendly",     instruction: "Warm, positive, and genuine. Light energy without being over-the-top.",        isPreset: true, isEnabled: true),
        Tone(id: UUID(), name: "Professional", instruction: "Clear, competent, respectful. Formal but not stiff.",                           isPreset: true, isEnabled: true),
        Tone(id: UUID(), name: "Direct",       instruction: "Short, direct, punchy. No filler. Gets to the point.",                         isPreset: true, isEnabled: true),
        Tone(id: UUID(), name: "Witty",        instruction: "Smart and playful. A touch of dry humor. Never forced.",                        isPreset: true, isEnabled: true),
        Tone(id: UUID(), name: "Casual",       instruction: "Relaxed, warm, natural. Contractions always. Match their energy exactly.",      isPreset: true, isEnabled: false),
        Tone(id: UUID(), name: "Formal",       instruction: "Polished and structured. Appropriate for official or high-stakes messages.",    isPreset: true, isEnabled: false),
        Tone(id: UUID(), name: "Empathetic",   instruction: "Warm, understanding, validating. Acknowledge feelings before responding.",      isPreset: true, isEnabled: false),
        Tone(id: UUID(), name: "Enthusiastic", instruction: "High energy, upbeat, genuine. Makes people feel good to hear from you.",        isPreset: true, isEnabled: false),
        Tone(id: UUID(), name: "Concise",      instruction: "One or two sentences max. Gets the point across without extra words.",          isPreset: true, isEnabled: false),
        Tone(id: UUID(), name: "Dating",       instruction: "Confident and genuine. Light wit when it fits. Never desperate, never try-hard.", isPreset: true, isEnabled: false),
    ]
}
