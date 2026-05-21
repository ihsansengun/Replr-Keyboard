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
        .background(KBColors.background)
    }

    // MARK: - Chat idle

    private var chatContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    model.isCollapsed = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "iphone.rear.camera")
                        .font(.system(size: 14))
                    Text("Capture this chat")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            Text("Minimises the keyboard so you can double-tap to screenshot")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Email idle

    private var emailContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Button { model.generateEmailReply() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 14))
                    Text("Generate from clipboard")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .opacity(hasClipboardText ? 1.0 : 0.45)
            .disabled(!hasClipboardText)

            Text("Copy the email you're replying to, then tap above")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 10)

            // Live clipboard status — uses hasStrings (no paste banner)
            HStack(spacing: 4) {
                if hasClipboardText {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
                Text(hasClipboardText ? "Email text ready" : "Nothing copied yet")
                    .font(.system(size: 11))
                    .foregroundColor(hasClipboardText ? .green : KBColors.textDim)
            }
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: hasClipboardText)

            Spacer(minLength: 0)
        }
        .onAppear {
            hasClipboardText = UIPasteboard.general.hasStrings
        }
    }
}
