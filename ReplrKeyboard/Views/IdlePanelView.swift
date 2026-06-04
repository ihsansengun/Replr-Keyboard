import SwiftUI

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
            VStack(alignment: .leading, spacing: 0) {
                // Top: how-to explanation
                VStack(alignment: .leading, spacing: 8) {
                    Badge("Capture", systemImage: "scope")

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

                Divider().opacity(0.2)

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
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(ReplrTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
            .elevatedSurface(.level1)

            // SPIKE — remove after Phase 0
            Button { model.runPhotosSpike() } label: {
                Text("🔬 Spike: read latest screenshot")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ReplrTheme.Color.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            if let spikeResult = model.spikeResult {
                Text(spikeResult)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
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
