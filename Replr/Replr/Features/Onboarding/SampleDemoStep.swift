import SwiftUI

/// First-win finale — a self-contained, credit-free simulation of real Replr usage.
/// A practice chat with a mocked Replr keyboard: it "reads" the chat → shows numbered reply
/// suggestions (mirroring RepliesPanelView) → tap one → Insert → it sends. No real keyboard,
/// no network, no credits. A line teaches the real globe-switch + screenshot gesture.
struct SampleDemoStep: View {
    let onFinish: () -> Void

    private enum Phase { case reading, replies, sent }
    @State private var phase: Phase = .reading
    @State private var selected: Int? = nil

    private let replies = [
        "Depends — are you asking me out? 😏",
        "I might be. What did you have in mind?",
        "For you, I'll make time this weekend.",
    ]

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    (Text("See it ")
                     + Text("in action").foregroundColor(ReplrTheme.Color.accent)
                     + Text("."))
                        .font(ReplrTheme.Font.serif(28, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Text("In a real chat: long-press 🌐 → pick Replr → screenshot. Here's what you'll see:")
                        .font(.system(size: 13))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                deviceMock.padding(.horizontal, 20)

                PrimaryButton(label: "Finish →", action: onFinish)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            phase = .reading
            selected = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    if phase == .reading { phase = .replies }
                }
            }
        }
    }

    // MARK: - Device mock (chat above, mocked Replr keyboard below)

    private var deviceMock: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                incoming("Hey, long time! 😊")
                incoming("So… are you free this weekend? 👀")
                if phase == .sent, let i = selected {
                    outgoing(replies[i])
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ReplrTheme.Color.surface)

            keyboardMock
        }
        .frame(maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(ReplrTheme.Color.glassBorder, lineWidth: 1))
    }

    private func incoming(_ text: String) -> some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(ReplrTheme.Color.textPrimary)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ReplrTheme.Color.surfaceRaised))
                .frame(maxWidth: 250, alignment: .leading)
            Spacer(minLength: 40)
        }
    }

    private func outgoing(_ text: String) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 40)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(ReplrTheme.Color.onAccent)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ReplrTheme.Color.brandGradient))
                .frame(maxWidth: 250, alignment: .trailing)
        }
    }

    // MARK: - Mocked Replr keyboard

    private var keyboardMock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ReplrMark(size: 13)
                Text("Replr")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                Spacer()
                Text("Casual")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.accent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(ReplrTheme.Color.accentSoft))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            switch phase {
            case .reading:
                HStack(spacing: 8) {
                    ProgressView().tint(ReplrTheme.Color.accent)
                    Text("Reading your chat…")
                        .font(.system(size: 13))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
            case .replies:
                VStack(spacing: 8) {
                    ForEach(0..<replies.count, id: \.self) { i in replyCardMock(i) }
                }
                .padding(.horizontal, 12)

                Button {
                    guard selected != nil else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { phase = .sent }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 13, weight: .bold))
                        Text("Insert reply").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(ReplrTheme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous).fill(ReplrTheme.Color.brandGradient))
                }
                .buttonStyle(.plain)
                .opacity(selected == nil ? 0.4 : 1)
                .disabled(selected == nil)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            case .sent:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
                    Text("Sent — that's the whole thing.").font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ReplrTheme.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .background(ReplrTheme.Color.bg)
    }

    /// Mirrors RepliesPanelView.replyCard.
    private func replyCardMock(_ idx: Int) -> some View {
        let isSel = selected == idx
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) { selected = idx }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text("\(idx + 1)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundColor(isSel ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary)
                    .frame(width: 18)
                Text(replies[idx])
                    .font(.system(size: 14))
                    .foregroundColor(isSel ? ReplrTheme.Color.accent : ReplrTheme.Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                .fill(isSel ? ReplrTheme.Color.accentSubtle : ReplrTheme.Color.surface))
            .overlay(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                .stroke(isSel ? ReplrTheme.Color.accent.opacity(0.6) : ReplrTheme.Color.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Sample demo (credit-free)") {
    SampleDemoStep(onFinish: {})
}
