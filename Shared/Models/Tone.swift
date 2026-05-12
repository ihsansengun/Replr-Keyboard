import Foundation

struct Tone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instruction: String
    var isPreset: Bool

    static let presets: [Tone] = [
        Tone(id: UUID(), name: "Casual",       instruction: "Relaxed, warm, natural. Contractions always. Match their energy exactly.", isPreset: true),
        Tone(id: UUID(), name: "Dating",       instruction: "Confident and genuine. Light wit when it fits. Never desperate, never try-hard.", isPreset: true),
        Tone(id: UUID(), name: "Professional", instruction: "Clear, competent, respectful. Formal but not stiff.", isPreset: true),
        Tone(id: UUID(), name: "Email",        instruction: "Structured reply. Appropriate formality read from the screenshot.", isPreset: true),
        Tone(id: UUID(), name: "Bold",         instruction: "Short, direct, punchy. No filler. Gets to the point.", isPreset: true),
    ]
}
