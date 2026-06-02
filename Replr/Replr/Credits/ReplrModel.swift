import Foundation

enum ReplrModel: String, CaseIterable, Identifiable {
    case gpt5_4         = "gpt-5.4"
    case claudeSonnet   = "claude-sonnet-4-6"

    var id: String { rawValue }

    /// Short label shown in keyboard header during dev mode.
    var shortLabel: String {
        switch self {
        case .gpt5_4:       return "GPT-5.4"
        case .claudeSonnet: return "Sonnet"
        }
    }

    /// Human-readable name shown in dev picker.
    var displayName: String {
        switch self {
        case .gpt5_4:       return "GPT-5.4"
        case .claudeSonnet: return "Claude Sonnet 4.6"
        }
    }

    /// Credits deducted per request.
    var creditsPerRequest: Int {
        switch self {
        case .gpt5_4:       return 7
        case .claudeSonnet: return 8
        }
    }

    /// Model ID sent to the backend API.
    var apiModelID: String { rawValue }

    /// The default model used for all users.
    static let defaultModel: ReplrModel = .claudeSonnet

    /// Init from an API model ID string stored in App Group.
    init?(apiID: String) {
        self.init(rawValue: apiID)
    }
}
