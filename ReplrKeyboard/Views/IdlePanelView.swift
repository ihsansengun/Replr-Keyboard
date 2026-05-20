import SwiftUI

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel

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
            CaptureZoneView()
                .padding(8)
            if !model.pendingContext.isEmpty {
                draftRow
            }
            Spacer(minLength: 0)
        }
    }

    private var draftRow: some View {
        Text(model.pendingContext)
            .font(.system(size: 9))
            .foregroundColor(KBColors.textDim)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(KBColors.deep)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(KBColors.borderHair, lineWidth: 0.5)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
    }

    // MARK: - Email idle

    private var emailContent: some View {
        VStack(spacing: 6) {
            Button { model.generateEmailReply() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 16))
                    Text("↑ Generate from clipboard")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(8)

            Text("Copy the email text first, then tap above")
                .font(.system(size: 10))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Capture Zone

private struct CaptureZoneView: View {
    @State private var ring1 = false
    @State private var ring2 = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                rippleCircle(expanding: ring1)
                rippleCircle(expanding: ring2)
                Image(systemName: "iphone.rear.camera")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(KBColors.accent)
            }
            .frame(height: 54)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    ring1 = true
                }
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false).delay(0.55)) {
                    ring2 = true
                }
            }

            Text("Back Tap to capture")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KBColors.accent)
            Text("screenshot → AI replies")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rippleCircle(expanding: Bool) -> some View {
        Circle()
            .stroke(KBColors.accent.opacity(0.75), lineWidth: 1.5)
            .frame(width: expanding ? 44 : 6,
                   height: expanding ? 44 : 6)
            .opacity(expanding ? 0 : 1)
    }
}
