import Foundation

/// Production models shown in Settings → AI Model (user-facing).
/// Dev models are the full list shown only in the dev picker.

enum ReplrModel: String, CaseIterable, Identifiable {
    // Production models (shown to all users)
    case claudeSonnet   = "claude-sonnet-4-6"
    case gpt5_4         = "gpt-5.4"

    // Dev-only models (visible in ModelPickerView, not in Settings)
    case gpt5_4mini     = "gpt-5.4-mini"
    case gpt5_5         = "gpt-5.5"

    var id: String { rawValue }

    /// Whether this model is shown in the user-facing Settings picker.
    var isProductionModel: Bool {
        switch self {
        case .claudeSonnet, .gpt5_4: return true
        case .gpt5_4mini, .gpt5_5:  return false
        }
    }

    /// Short label shown in keyboard header during dev mode.
    var shortLabel: String {
        switch self {
        case .claudeSonnet: return "Sonnet"
        case .gpt5_4:       return "GPT-5.4"
        case .gpt5_4mini:   return "5.4m"
        case .gpt5_5:       return "GPT-5.5"
        }
    }

    /// Human-readable name.
    var displayName: String {
        switch self {
        case .claudeSonnet: return "Claude Sonnet 4.6"
        case .gpt5_4:       return "GPT-5.4"
        case .gpt5_4mini:   return "GPT-5.4 Mini"
        case .gpt5_5:       return "GPT-5.5"
        }
    }

    /// Credits deducted per request.
    var creditsPerRequest: Int {
        switch self {
        case .claudeSonnet: return 8
        case .gpt5_4:       return 7
        case .gpt5_4mini:   return 2
        case .gpt5_5:       return 15
        }
    }

    /// Model ID sent to the backend API.
    var apiModelID: String { rawValue }

    /// Default for all users.
    static let defaultModel: ReplrModel = .claudeSonnet

    /// Init from stored API model ID string.
    init?(apiID: String) {
        self.init(rawValue: apiID)
    }
}
