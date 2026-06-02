import Foundation

enum ReplrModel: String, CaseIterable, Identifiable {
    case gpt4_1mini     = "gpt-4.1-mini"
    case gpt4_1         = "gpt-4.1"
    case gpt5_4mini     = "gpt-5.4-mini"
    case gpt5_4         = "gpt-5.4"
    case claudeSonnet   = "claude-sonnet-4-6"

    var id: String { rawValue }

    /// Short label shown in keyboard header during dev mode.
    var shortLabel: String {
        switch self {
        case .gpt4_1mini:   return "4.1m"
        case .gpt4_1:       return "4.1"
        case .gpt5_4mini:   return "5.4m"
        case .gpt5_4:       return "5.4"
        case .claudeSonnet: return "Sonnet"
        }
    }

    /// Human-readable name shown in dev picker.
    var displayName: String {
        switch self {
        case .gpt4_1mini:   return "GPT-4.1 Mini"
        case .gpt4_1:       return "GPT-4.1"
        case .gpt5_4mini:   return "GPT-5.4 Mini"
        case .gpt5_4:       return "GPT-5.4"
        case .claudeSonnet: return "Claude Sonnet 4.6"
        }
    }

    /// Credits deducted per request.
    var creditsPerRequest: Int {
        switch self {
        case .gpt4_1mini:   return 1
        case .gpt4_1:       return 3
        case .gpt5_4mini:   return 2
        case .gpt5_4:       return 7
        case .claudeSonnet: return 8
        }
    }

    /// Model ID sent to the backend API.
    var apiModelID: String { rawValue }

    /// The default model used for all users.
    static let defaultModel: ReplrModel = .gpt4_1mini

    /// Init from an API model ID string stored in App Group.
    init?(apiID: String) {
        self.init(rawValue: apiID)
    }
}
