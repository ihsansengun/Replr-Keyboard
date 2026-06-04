import SwiftUI
import Combine

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel
    @State private var hasClipboardText: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model)
            if model.inputMode == .chat {
                chatContent
            } else {
                emailContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
    }

    // MARK: - Chat idle

    private var chatContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                // Language-agnostic looping demo of the 2 steps
                CaptureStepsAnimation()
                    .frame(height: 150)
                    .padding(.top, 14)
                    .padding(.horizontal, 12)

                Text("Screenshot a chat and I'll draft the replies.")
                    .font(.system(size: 13))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)

                // Single, distinct CTA — tapping visibly lowers the keyboard
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("Start")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(ReplrTheme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                            .overlay(ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm))
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? ReplrTheme.Color.accent.opacity(0.45)
                            : .black.opacity(0.10),
                        radius: colorScheme == .dark ? 14 : 6,
                        x: 0, y: colorScheme == .dark ? 5 : 3
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .background(ReplrTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
            .elevatedSurface(.level1)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Email idle

    private var emailContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Button { model.generateEmailReply() } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasClipboardText ? "doc.on.clipboard.fill" : "doc.on.clipboard")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Generate from clipboard")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(hasClipboardText ? ReplrTheme.Color.onAccent : ReplrTheme.Color.accent.opacity(0.40))
                .padding(.horizontal, 24)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .fill(hasClipboardText ? ReplrTheme.Color.accent : ReplrTheme.Color.surface)
                        .overlay(hasClipboardText ? ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm) : nil)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .strokeBorder(hasClipboardText ? Color.clear : ReplrTheme.Color.accent.opacity(0.25), lineWidth: 1)
                )
                .shadow(
                    color: colorScheme == .dark
                        ? ReplrTheme.Color.accent.opacity(hasClipboardText ? 0.45 : 0)
                        : .black.opacity(hasClipboardText ? 0.10 : 0),
                    radius: colorScheme == .dark ? 14 : 6,
                    x: 0, y: colorScheme == .dark ? 5 : 3
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasClipboardText)
            .padding(.horizontal, 16)

            HStack(spacing: 4) {
                if hasClipboardText {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(ReplrTheme.Color.accent)
                }
                Text(hasClipboardText ? "Email ready — tap to generate" : "Copy an email, then tap to generate")
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(hasClipboardText ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            }
            .padding(.top, 10)
            .animation(.easeInOut(duration: 0.2), value: hasClipboardText)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            hasClipboardText = UIPasteboard.general.hasStrings
        }
    }
}

// MARK: - Capture steps animation (language-agnostic, pure SwiftUI)

/// A small looping demo showing the two capture steps with no words:
/// ① the keyboard slides down to a slim bar, ② a screenshot flash, then replies appear.
/// Numbers (①/②) are the only "text" — they read in every language.
/// Falls back to a static two-step graphic when Reduce Motion is on.
private struct CaptureStepsAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 = rest (keyboard up), 1 = minimize, 2 = screenshot, 3 = replies.
    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.95, on: .main, in: .common).autoconnect()

    private var minimized: Bool { phase >= 1 }
    private var flashing: Bool { phase == 2 }
    private var showReplies: Bool { phase == 3 }
    private var activeStep: Int { phase >= 2 ? 2 : 1 }

    var body: some View {
        if reduceMotion {
            staticFallback
        } else {
            HStack(spacing: 16) {
                phoneMock
                legend
            }
            .frame(maxWidth: .infinity)
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.5)) { phase = (phase + 1) % 4 }
            }
        }
    }

    // MARK: Phone mock

    private var phoneMock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ReplrTheme.Color.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1.5)
                )

            VStack(spacing: 5) {
                bubble(width: 52, sent: false)
                bubble(width: 38, sent: true)
                bubble(width: 56, sent: false)
                if minimized {
                    bubble(width: 44, sent: true)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 0)

                // keyboard → slim bar
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(ReplrTheme.Color.accent.opacity(minimized ? 0.9 : 0.20))
                        .frame(height: minimized ? 11 : 42)

                    if !minimized {
                        VStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in keyRow }
                        }
                        .padding(.horizontal, 7)
                        .transition(.opacity)
                    }

                    if showReplies {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in replyChip }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .padding(10)

            // screenshot flash + shutter glyph
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .opacity(flashing ? 0.85 : 0)
            if flashing {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(ReplrTheme.Color.accent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 104, height: 138)
        .clipped()
    }

    private func bubble(width: CGFloat, sent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(sent ? ReplrTheme.Color.accent.opacity(0.55)
                       : ReplrTheme.Color.textSecondary.opacity(0.22))
            .frame(width: width, height: 9)
            .frame(maxWidth: .infinity, alignment: sent ? .trailing : .leading)
    }

    private var keyRow: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(ReplrTheme.Color.textSecondary.opacity(0.35))
            .frame(height: 4)
    }

    private var replyChip: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(ReplrTheme.Color.onAccent)
            .frame(width: 17, height: 5)
    }

    // MARK: Legend (① minimize → ② screenshot)

    private var legend: some View {
        VStack(spacing: 8) {
            legendItem(1, "keyboard.chevron.compact.down", active: activeStep == 1)
            Image(systemName: "arrow.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ReplrTheme.Color.textTertiary)
            legendItem(2, "camera.viewfinder", active: activeStep == 2)
        }
    }

    private func legendItem(_ n: Int, _ system: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundColor(active ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(active ? ReplrTheme.Color.accent : ReplrTheme.Color.surface))
                .overlay(Circle().stroke(ReplrTheme.Color.glassBorder, lineWidth: active ? 0 : 1))
            Image(systemName: system)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(active ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary)
        }
        .opacity(active ? 1 : 0.5)
        .scaleEffect(active ? 1 : 0.95)
    }

    // MARK: Reduce Motion fallback (static two-step)

    private var staticFallback: some View {
        HStack(spacing: 14) {
            staticStep(1, "keyboard.chevron.compact.down")
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ReplrTheme.Color.textTertiary)
            staticStep(2, "camera.viewfinder")
        }
        .frame(maxWidth: .infinity)
    }

    private func staticStep(_ n: Int, _ system: String) -> some View {
        VStack(spacing: 7) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundColor(ReplrTheme.Color.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ReplrTheme.Color.accent))
            Image(systemName: system)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ReplrTheme.Color.accent)
        }
    }
}
