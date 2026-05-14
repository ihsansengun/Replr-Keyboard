import Foundation

struct Tone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instruction: String
    var isPreset: Bool

    static let presets: [Tone] = [
        Tone(id: UUID(), name: "Casual",       instruction: "Relaxed, warm, natural. Contractions always. Match their energy exactly.", isPreset: true),
        Tone(id: UUID(), name: "Friendly",     instruction: "Warm, positive, and genuine. Light energy without being over-the-top.", isPreset: true),
        Tone(id: UUID(), name: "Dating",       instruction: "Confident and genuine. Light wit when it fits. Never desperate, never try-hard.", isPreset: true),
        Tone(id: UUID(), name: "Professional", instruction: "Clear, competent, respectful. Formal but not stiff.", isPreset: true),
        Tone(id: UUID(), name: "Formal",       instruction: "Polished and structured. Appropriate for official or high-stakes messages.", isPreset: true),
        Tone(id: UUID(), name: "Email",        instruction: "Structured email reply. Match the formality of the email. Clear, purposeful, no fluff.", isPreset: true),
        Tone(id: UUID(), name: "Bold",         instruction: "Short, direct, punchy. No filler. Gets to the point.", isPreset: true),
        Tone(id: UUID(), name: "Witty",        instruction: "Smart and playful. A touch of dry humor. Never forced.", isPreset: true),
    ]
}
