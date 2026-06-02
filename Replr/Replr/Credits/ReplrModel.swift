import Foundation

enum ReplrModel: String, CaseIterable, Identifiable {
    // Production models (Settings → AI Model)
    case claudeSonnet   = "claude-sonnet-4-6"
    case gpt5_4         = "gpt-5.4"

    // Dev-only — available in ModelPickerView for testing
    case claudeOpus     = "claude-opus-4-6"
    case gpt5_5         = "gpt-5.5"
    case grok4          = "grok-4"
    case grok4_3        = "grok-4.3"
    case gpt5_4mini     = "gpt-5.4-mini"

    var id: String { rawValue }

    var isProductionModel: Bool {
        switch self {
        case .claudeSonnet, .gpt5_4: return true
        default: return false
        }
    }

    var shortLabel: String {
        switch self {
        case .claudeSonnet: return "Sonnet"
        case .gpt5_4:       return "GPT-5.4"
        case .claudeOpus:   return "Opus"
        case .gpt5_5:       return "GPT-5.5"
        case .grok4:        return "Grok 4"
        case .grok4_3:      return "Grok 4.3"
        case .gpt5_4mini:   return "5.4m"
        }
    }

    var displayName: String {
        switch self {
        case .claudeSonnet: return "Claude Sonnet 4.6"
        case .gpt5_4:       return "GPT-5.4"
        case .claudeOpus:   return "Claude Opus 4.6 ★"
        case .gpt5_5:       return "GPT-5.5 ★"
        case .grok4:        return "Grok 4"
        case .grok4_3:      return "Grok 4.3"
        case .gpt5_4mini:   return "GPT-5.4 Mini"
        }
    }

    var creditsPerRequest: Int {
        switch self {
        case .claudeSonnet: return 8
        case .gpt5_4:       return 7
        case .claudeOpus:   return 15
        case .gpt5_5:       return 15
        case .grok4:        return 7
        case .grok4_3:      return 2
        case .gpt5_4mini:   return 2
        }
    }

    var apiModelID: String { rawValue }
    static let defaultModel: ReplrModel = .claudeSonnet

    init?(apiID: String) {
        self.init(rawValue: apiID)
    }
}
