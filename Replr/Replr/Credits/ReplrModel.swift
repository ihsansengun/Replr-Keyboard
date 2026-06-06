import Foundation
import SwiftUI

enum ReplrModel: String, CaseIterable, Identifiable {
    // Production models (Settings → AI Model)
    case claudeSonnet   = "claude-sonnet-4-6"
    case gpt5_4         = "gpt-5.4"

    // Dev-only — available in ModelPickerView for testing
    case claudeOpus     = "claude-opus-4-6"
    case gpt5_5         = "gpt-5.5"
    case gemini         = "gemini-3.1-pro-preview"
    case geminiFlash    = "gemini-3-flash-preview"
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
        case .gemini:       return "Gemini"
        case .geminiFlash:  return "Gem Flash"
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
        case .gemini:       return "Gemini 3.1 Pro ★"
        case .geminiFlash:  return "Gemini 3 Flash"
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
        case .gemini:       return 6
        case .geminiFlash:  return 3
        case .grok4:        return 7
        case .grok4_3:      return 2
        case .gpt5_4mini:   return 2
        }
    }

    var apiModelID: String { rawValue }
    static let defaultModel: ReplrModel = .claudeSonnet

    /// Approximate Arena Elo (human preference leaderboard) for display in dev picker.
    var arenaElo: String {
        switch self {
        case .gpt5_5:       return "1506"
        case .gemini:       return "1505"
        case .geminiFlash:  return "—"
        case .claudeOpus:   return "1490"
        case .gpt5_4:       return "1495"
        case .grok4:        return "1496"
        case .claudeSonnet: return "1460"
        case .grok4_3:      return "—"
        case .gpt5_4mini:   return "—"
        }
    }

    /// SwiftUI color for Elo — green for top tier, dimmer otherwise.
    var eloColor: Color {
        switch self {
        case .gpt5_5, .gemini, .claudeOpus, .grok4: return Color.green.opacity(0.85)
        case .gpt5_4, .claudeSonnet:                 return Color.orange.opacity(0.85)
        case .geminiFlash:                           return Color.gray.opacity(0.6)
        default:                                      return Color.gray.opacity(0.6)
        }
    }

    /// Approximate cost per Replr request (~2100 input + 450 output tokens, PNG screenshot).
    var costPerRequest: String {
        switch self {
        case .claudeSonnet: return "$0.013"
        case .gpt5_4:       return "$0.011"
        case .claudeOpus:   return "$0.022"
        case .gpt5_5:       return "$0.025"
        case .gemini:       return "$0.015"
        case .geminiFlash:  return "$0.004"
        case .grok4:        return "$0.011"
        case .grok4_3:      return "$0.004"
        case .gpt5_4mini:   return "$0.003"
        }
    }

    /// SwiftUI color for cost — green = cheap, red = expensive.
    var costColor: Color {
        switch self {
        case .grok4_3, .gpt5_4mini, .geminiFlash: return Color.green.opacity(0.85)
        case .claudeSonnet, .gpt5_4, .grok4:    return Color.orange.opacity(0.85)
        case .claudeOpus, .gpt5_5, .gemini:     return Color.red.opacity(0.75)
        }
    }

    init?(apiID: String) {
        self.init(rawValue: apiID)
    }
}
