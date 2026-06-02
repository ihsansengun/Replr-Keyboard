import SwiftUI

struct ErrorPanelView: View {
    let message: String
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model)
            errorContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
    }

    // MARK: - Error parsing

    private var parsed: ParsedError { ParsedError(raw: message) }

    private var errorContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(systemName: parsed.icon)
                .font(.system(size: 22))
                .foregroundColor(parsed.iconColor)
                .padding(.bottom, 8)

            Text(parsed.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(parsed.subtitle)
                .font(.system(size: 11))
                .foregroundColor(ReplrTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 20)
                .padding(.top, 4)

            // Active model badge — helps identify which model caused the error
            if AppGroupService.shared.devMode {
                Text("Model: \(AppGroupService.shared.selectedModelShortLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ReplrTheme.Color.accent.opacity(0.7))
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button { model.retryGeneration() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                        Text(parsed.primaryAction)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(ReplrTheme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(ReplrTheme.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                    .shadow(color: ReplrTheme.Color.accent.opacity(0.55), radius: 18, x: 0, y: 6)
                }
                .buttonStyle(.plain)

                // Secondary action for model/credit errors
                if let secondary = parsed.secondaryAction {
                    Text(secondary)
                        .font(.system(size: 11))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Error parser

private struct ParsedError {
    let raw: String

    var icon: String {
        switch category {
        case .credits:   return "creditcard.fill"
        case .model:     return "cpu.fill"
        case .network:   return "wifi.slash"
        case .rateLimit: return "clock.fill"
        default:         return "exclamationmark.triangle.fill"
        }
    }

    var iconColor: Color {
        switch category {
        case .credits:   return ReplrTheme.Color.accent
        case .model:     return Color.orange
        case .network:   return Color.orange
        case .rateLimit: return Color.orange
        default:         return ReplrTheme.Color.accent.opacity(0.85)
        }
    }

    var title: String {
        switch category {
        case .credits:   return "Out of credits"
        case .model:     return "Model error"
        case .network:   return "Connection failed"
        case .rateLimit: return "Rate limit hit"
        case .auth:      return "API key invalid"
        case .server:    return "Service unavailable"
        default:         return "Couldn't generate replies"
        }
    }

    var subtitle: String {
        switch category {
        case .credits:
            return "Top up credits in Replr to keep going."
        case .model:
            return "This model failed. Try switching to Sonnet in Settings."
        case .network:
            return "Check your internet connection and try again."
        case .rateLimit:
            return "Too many requests. Wait a moment then try again."
        case .auth:
            return "API key issue — check Settings."
        case .server:
            return "The AI service is having issues. Try again in a moment."
        default:
            // Show truncated raw message if nothing matched
            let cleaned = raw
                .replacingOccurrences(of: "Something went wrong. Tap Capture to retry.", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { return "Something went wrong. Tap Capture to retry." }
            return cleaned.count > 100 ? String(cleaned.prefix(100)) + "…" : cleaned
        }
    }

    var primaryAction: String { "Try again" }

    var secondaryAction: String? {
        switch category {
        case .credits: return "Open Replr to top up"
        case .model:   return "Switch model in Settings → AI Model"
        default:       return nil
        }
    }

    // MARK: - Category detection

    private enum Category {
        case credits, model, network, rateLimit, auth, server, generic
    }

    private var category: Category {
        let r = raw.lowercased()
        if r.contains("insufficient_credits") || r.contains("out of credits") { return .credits }
        if r.contains("trial_exhausted") { return .credits }
        if r.contains("api key") || r.contains("incorrect api") || r.contains("401") || r.contains("authentication") { return .auth }
        if r.contains("credits") || r.contains("license") || r.contains("403") || r.contains("team doesn") { return .model }
        if r.contains("500") || r.contains("502") || r.contains("503") || r.contains("service unavailable") { return .server }
        if r.contains("429") || r.contains("rate limit") { return .rateLimit }
        if r.contains("network") || r.contains("internet") || r.contains("timeout") || r.contains("timed out") || r.contains("connection") { return .network }
        if r.contains("400") || r.contains("unsupported") || r.contains("model") { return .model }
        return .generic
    }
}
