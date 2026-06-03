import AppIntents

enum ReplyTone: String, AppEnum {
    case friendly         = "Friendly"
    case casual           = "Casual"
    case direct           = "Direct"
    case witty            = "Witty"
    case professional     = "Professional"
    case empathetic       = "Empathetic"
    case enthusiastic     = "Enthusiastic"
    case concise          = "Concise"
    case formal           = "Formal"
    case dating           = "Dating"
    case joker            = "Joker"
    case passiveAggressive = "Passive Aggressive"
    case genZ             = "Gen Z"
    case seductive        = "Seductive"
    case sarcastic        = "Sarcastic"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tone"
    static var caseDisplayRepresentations: [ReplyTone: DisplayRepresentation] = [
        .friendly:          "Friendly",
        .casual:            "Casual",
        .direct:            "Direct",
        .witty:             "Witty",
        .professional:      "Professional",
        .empathetic:        "Empathetic",
        .enthusiastic:      "Enthusiastic",
        .concise:           "Concise",
        .formal:            "Formal",
        .dating:            "Dating",
        .joker:             "Joker",
        .passiveAggressive: "Passive Aggressive",
        .genZ:              "Gen Z",
        .seductive:         "Seductive",
        .sarcastic:         "Sarcastic",
    ]

    var tone: Tone {
        Tone.presets.first { $0.name == rawValue } ?? Tone.presets[0]
    }
}
