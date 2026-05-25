import AppIntents

enum ReplyTone: String, AppEnum {
    case friendly     = "Friendly"
    case professional = "Professional"
    case direct       = "Direct"
    case witty        = "Witty"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tone"
    static var caseDisplayRepresentations: [ReplyTone: DisplayRepresentation] = [
        .friendly:     "Friendly",
        .professional: "Professional",
        .direct:       "Direct",
        .witty:        "Witty",
    ]

    var tone: Tone {
        Tone.presets.first { $0.name == rawValue } ?? Tone.presets[0]
    }
}
