import SwiftUI

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel
    @State private var hasClipboardText: Bool = false

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
            VStack(alignment: .leading, spacing: 0) {
                // Top: how-to explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("HOW TO CAPTURE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .tracking(0.8)

                    Text("Open the chat, then collapse this keyboard — Replr records what's on screen when you triple-tap.")
                        .font(.system(size: 13))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 5) {
                        Text("✦")
                            .font(.system(size: 10))
                            .foregroundColor(ReplrTheme.Color.accent)
                        Text("Anything you've typed is sent as context automatically")
                            .font(.system(size: 11.5))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(14)

                ReplrTheme.Color.border.frame(height: 0.5)

                // Bottom: prompt + small action button
                HStack {
                    Text("Ready? Collapse to start")
                        .font(.system(size: 12))
                        .foregroundColor(ReplrTheme.Color.textSecondary)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = true }
                    } label: {
                        Text("Start capture ↓")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.onAccent)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(ReplrTheme.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(ReplrTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Email idle

    private var emailContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Button { model.generateEmailReply() } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasClipboardText ? "doc.on.clipboard.fill" : "doc.on.clipboard")
                        .font(.system(size: 14))
                    Text("Generate from clipboard")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(hasClipboardText ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(ReplrTheme.Color.accent.opacity(hasClipboardText ? 1.0 : 0.30))
                .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .disabled(!hasClipboardText)

            HStack(spacing: 4) {
                if hasClipboardText {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(ReplrTheme.Color.success)
                }
                Text(hasClipboardText ? "Email ready — tap to generate" : "Copy an email, then tap to generate")
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(hasClipboardText ? ReplrTheme.Color.success : ReplrTheme.Color.textSecondary)
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
