import Foundation
import SwiftUI

enum ReplrModel: String, CaseIterable, Identifiable {
    // User-facing quality tiers — the only ids non-dev builds send. The backend
    // resolves which vendor model each tier means today (services/models.ts
    // TIERS), so repointing a tier never needs an app release and users never
    // see vendor names.
    case balanced       = "balanced"
    case max            = "max"

    // Raw vendor models — dev-only
    case claudeSonnet   = "claude-sonnet-4-6"
    case gpt5_4         = "gpt-5.4"

    // Dev-only — available in ModelPickerView for testing
    case claudeOpus     = "claude-opus-4-6"
    case claudeOpus47   = "claude-opus-4-7"      // independent #1 human-like writer
    case claudeHaiku45  = "claude-haiku-4-5"     // fast + cheap
    case gpt5_5         = "gpt-5.5"
    case gemini         = "gemini-3.1-pro-preview"   // Pro at HIGH thinking
    case geminiProLow   = "gemini-3.1-pro-low"        // Pro at LOW thinking (routes to the same API model)
    case geminiFlash    = "gemini-3-flash-preview"
    case gemini35Flash   = "gemini-3.5-flash"           // newest Flash
    case geminiFlashLite = "gemini-3.1-flash-lite"      // fastest / cheapest
    case gemini25Pro     = "gemini-2.5-pro"             // prior-gen Pro
    case grok4          = "grok-4"
    case grok4_3        = "grok-4.3"
    case gpt5_4mini     = "gpt-5.4-mini"

    var id: String { rawValue }

    var isProductionModel: Bool {
        switch self {
        case .balanced, .max: return true   // user-facing tiers; vendor models are dev-only
        default: return false
        }
    }

    var shortLabel: String {
        switch self {
        case .balanced:     return "Balanced"
        case .max:          return "Max"
        case .claudeSonnet: return "Sonnet"
        case .gpt5_4:       return "GPT-5.4"
        case .claudeOpus:   return "Opus"
        case .claudeOpus47: return "Opus 4.7"
        case .claudeHaiku45: return "Haiku 4.5"
        case .gpt5_5:       return "GPT-5.5"
        case .gemini:       return "Pro Hi"
        case .geminiProLow: return "Pro Lo"
        case .geminiFlash:  return "Gem Flash"
        case .gemini35Flash:   return "3.5 Fl"
        case .geminiFlashLite: return "Fl Lite"
        case .gemini25Pro:     return "2.5 Pro"
        case .grok4:        return "Grok 4"
        case .grok4_3:      return "Grok 4.3"
        case .gpt5_4mini:   return "5.4m"
        }
    }

    var displayName: String {
        switch self {
        case .balanced:     return "Balanced · tier"
        case .max:          return "Max · tier"
        case .claudeSonnet: return "Claude Sonnet 4.6"
        case .gpt5_4:       return "GPT-5.4"
        case .claudeOpus:   return "Claude Opus 4.6 ★"
        case .claudeOpus47: return "Claude Opus 4.7 ★"
        case .claudeHaiku45: return "Claude Haiku 4.5"
        case .gpt5_5:       return "GPT-5.5 ★"
        case .gemini:       return "Gemini Pro · High ★"
        case .geminiProLow: return "Gemini Pro · Low"
        case .geminiFlash:  return "Gemini 3 Flash"
        case .gemini35Flash:   return "Gemini 3.5 Flash"
        case .geminiFlashLite: return "Gemini 3.1 Flash Lite"
        case .gemini25Pro:     return "Gemini 2.5 Pro"
        case .grok4:        return "Grok 4"
        case .grok4_3:      return "Grok 4.3"
        case .gpt5_4mini:   return "GPT-5.4 Mini"
        }
    }

    var creditsPerRequest: Int {
        switch self {
        case .balanced:     return 4
        case .max:          return 6
        case .claudeSonnet: return 8
        case .gpt5_4:       return 7
        case .claudeOpus:   return 15
        case .claudeOpus47: return 15
        case .claudeHaiku45: return 3
        case .gpt5_5:       return 15
        case .gemini:       return 6
        case .geminiProLow: return 6
        case .geminiFlash:  return 3
        case .gemini35Flash:   return 4
        case .geminiFlashLite: return 2
        case .gemini25Pro:     return 4
        case .grok4:        return 7
        case .grok4_3:      return 2
        case .gpt5_4mini:   return 2
        }
    }

    var apiModelID: String { rawValue }
    static let defaultModel: ReplrModel = .balanced

    /// Approximate Arena Elo (human preference leaderboard) for display in dev picker.
    var arenaElo: String {
        switch self {
        case .balanced, .max: return "—"
        case .gpt5_5:       return "1506"
        case .gemini:       return "1505"
        case .geminiProLow: return "—"
        case .geminiFlash:  return "—"
        case .gemini35Flash:   return "—"
        case .geminiFlashLite: return "—"
        case .gemini25Pro:     return "—"
        case .claudeOpus:   return "1490"
        case .claudeOpus47: return "1501"
        case .claudeHaiku45: return "1407"
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
        case .gpt5_5, .gemini, .claudeOpus, .claudeOpus47, .grok4: return Color.green.opacity(0.85)
        case .gpt5_4, .claudeSonnet:                 return Color.orange.opacity(0.85)
        case .geminiFlash:                           return Color.gray.opacity(0.6)
        default:                                      return Color.gray.opacity(0.6)
        }
    }

    /// Approximate cost per Replr request (~2100 input + 450 output tokens, PNG screenshot).
    var costPerRequest: String {
        switch self {
        case .balanced:     return "$0.007"   // today's underlying: gemini-3.5-flash
        case .max:          return "$0.015"   // today's underlying: gemini-3.1-pro-preview
        case .claudeSonnet: return "$0.013"
        case .gpt5_4:       return "$0.011"
        case .claudeOpus:   return "$0.022"
        case .claudeOpus47: return "$0.022"
        case .claudeHaiku45: return "$0.004"
        case .gpt5_5:       return "$0.025"
        case .gemini:       return "$0.015"
        case .geminiProLow: return "$0.015"
        case .geminiFlash:  return "$0.004"
        case .gemini35Flash:   return "$0.007"
        case .geminiFlashLite: return "$0.001"
        case .gemini25Pro:     return "$0.007"
        case .grok4:        return "$0.011"
        case .grok4_3:      return "$0.004"
        case .gpt5_4mini:   return "$0.003"
        }
    }

    /// SwiftUI color for cost — green = cheap, red = expensive.
    var costColor: Color {
        switch self {
        case .grok4_3, .gpt5_4mini, .geminiFlash, .geminiFlashLite, .claudeHaiku45: return Color.green.opacity(0.85)
        case .claudeSonnet, .gpt5_4, .grok4, .gemini35Flash, .gemini25Pro, .balanced: return Color.orange.opacity(0.85)
        case .claudeOpus, .claudeOpus47, .gpt5_5, .gemini, .geminiProLow, .max: return Color.red.opacity(0.75)
        }
    }

    init?(apiID: String) {
        self.init(rawValue: apiID)
    }
}
