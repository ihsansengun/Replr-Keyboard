import AppIntents

enum ReplyTone: String, AppEnum {
    case casual = "Casual"
    case dating = "Dating"
    case professional = "Professional"
    case email = "Email"
    case bold = "Bold"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tone"
    static var caseDisplayRepresentations: [ReplyTone: DisplayRepresentation] = [
        .casual:       "Casual",
        .dating:       "Dating",
        .professional: "Professional",
        .email:        "Email",
        .bold:         "Bold",
    ]

    var tone: Tone {
        Tone.presets.first { $0.name == rawValue } ?? Tone.presets[0]
    }
}
