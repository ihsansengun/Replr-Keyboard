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
            Button { model.isCollapsed = true } label: {
                CaptureZoneView()
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, model.pendingContext.isEmpty ? 8 : 4)
            }
            .buttonStyle(.plain)
            .frame(maxHeight: .infinity)
            if !model.pendingContext.isEmpty {
                draftRow
            }
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
            Spacer(minLength: 0)
            Button { model.generateEmailReply() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 13))
                    Text("↑ Generate from clipboard")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

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
    @State private var animating = false

    var body: some View {
        ZStack {
            KBColors.surface
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
                    guard !animating else { return }
                    animating = true
                    withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                        ring1 = true
                    }
                    withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false).delay(0.55)) {
                        ring2 = true
                    }
                }

                Text("Tap to minimise, then Back Tap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(KBColors.accent)
                Text("screenshot → AI replies")
                    .font(.system(size: 11))
                    .foregroundColor(KBColors.textDim)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rippleCircle(expanding: Bool) -> some View {
        Circle()
            .stroke(KBColors.accent.opacity(0.75), lineWidth: 1.5)
            .frame(width: expanding ? 44 : 6,
                   height: expanding ? 44 : 6)
            .opacity(expanding ? 0 : 1)
            .offset(y: -2)
    }
}
