import SwiftUI

/// First-win finale — a faithful mock of *real* Replr usage: a chat with the Replr keyboard
/// below it showing numbered reply suggestions; tap one, then Insert, and it sends. The reply
/// cards mirror the real keyboard's RepliesPanelView. No network, no credits.
struct SampleDemoStep: View {
    let onFinish: () -> Void

    @State private var selected: Int? = nil
    @State private var inserted = false

    private let incoming = "So… are you free this weekend? 👀"
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
                    Text(inserted
                         ? "That's the whole thing — pick a reply, it's in."
                         : "Replr read this chat. Tap a reply, then Insert.")
                        .font(.system(size: 14))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                deviceMock.padding(.horizontal, 20)

                PrimaryButton(label: "Finish →", action: onFinish)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Device mock (chat above, Replr keyboard below)

    private var deviceMock: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                chatBubble(incoming, outgoing: false)
                if inserted, let i = selected {
                    chatBubble(replies[i], outgoing: true)
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

    private func chatBubble(_ text: String, outgoing: Bool) -> some View {
        HStack(spacing: 0) {
            if outgoing { Spacer(minLength: 48) }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(outgoing ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textPrimary)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(outgoing ? AnyShapeStyle(ReplrTheme.Color.brandGradient)
                                       : AnyShapeStyle(ReplrTheme.Color.surfaceRaised))
                )
                .frame(maxWidth: 230, alignment: outgoing ? .trailing : .leading)
            if !outgoing { Spacer(minLength: 48) }
        }
    }

    // MARK: - Replr keyboard mock

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

            if inserted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
                    Text("Sent — nice one.").font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ReplrTheme.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            } else {
                VStack(spacing: 8) {
                    ForEach(0..<replies.count, id: \.self) { i in replyCardMock(i) }
                }
                .padding(.horizontal, 12)

                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { inserted = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 13, weight: .bold))
                        Text("Insert reply").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(ReplrTheme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .fill(ReplrTheme.Color.brandGradient)
                    )
                }
                .buttonStyle(.plain)
                .opacity(selected == nil ? 0.4 : 1)
                .disabled(selected == nil)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(ReplrTheme.Color.bg)
    }

    /// Mirrors RepliesPanelView.replyCard — numbered, surface card, accent when selected.
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
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .fill(isSel ? ReplrTheme.Color.accentSubtle : ReplrTheme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .stroke(isSel ? ReplrTheme.Color.accent.opacity(0.6) : ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Sample demo") {
    SampleDemoStep(onFinish: {})
}
