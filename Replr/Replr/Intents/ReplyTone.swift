import AppIntents

enum ReplyTone: String, AppEnum {
    case casual = "Casual"
    case friendly = "Friendly"
    case dating = "Dating"
    case professional = "Professional"
    case formal = "Formal"
    case bold = "Bold"
    case witty = "Witty"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tone"
    static var caseDisplayRepresentations: [ReplyTone: DisplayRepresentation] = [
        .casual:       "Casual",
        .friendly:     "Friendly",
        .dating:       "Dating",
        .professional: "Professional",
        .formal:       "Formal",
        .bold:         "Bold",
        .witty:        "Witty",
    ]

    var tone: Tone {
        Tone.presets.first { $0.name == rawValue } ?? Tone.presets[0]
    }
}
