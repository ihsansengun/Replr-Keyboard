import SwiftUI

/// First-win finale — a *live* guided practice. A realistic chat with a real text field that
/// opens the keyboard; the user switches to Replr (globe), screenshots this chat, and the real
/// Replr keyboard inserts a reply into the field. We detect the inserted text and celebrate.
/// "Skip" always available in case Replr isn't ready.
struct SampleDemoStep: View {
    let onFinish: () -> Void

    @State private var draft = ""
    @State private var done = false
    @State private var didScreenshot = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                chatHeader
                Rectangle().fill(ReplrTheme.Color.glassBorder).frame(height: 0.5)
                messages
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
        }
        .onChange(of: draft) { newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { done = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            withAnimation { didScreenshot = true }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("Practice")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.accent)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(ReplrTheme.Color.accentSoft))
            Spacer()
            Button("Skip →") { onFinish() }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ReplrTheme.Color.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var chatHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(ReplrTheme.Color.brandGradient).frame(width: 36, height: 36)
                Text("A").font(.system(size: 16, weight: .bold)).foregroundColor(ReplrTheme.Color.onAccent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Alex").font(.system(size: 16, weight: .semibold)).foregroundColor(ReplrTheme.Color.textPrimary)
                Text("Active now").font(.system(size: 12)).foregroundColor(ReplrTheme.Color.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private var messages: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                incoming("Hey, long time! 😊")
                incoming("So… are you free this weekend? 👀")
                if done {
                    outgoing(draft)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
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

    // MARK: - Bottom (coachmark + input, pinned above the keyboard)

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if done {
                successCard
            } else {
                coachmark
            }
            inputBar
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(ReplrTheme.Color.bg)
    }

    private var coachmark: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 14))
                .foregroundColor(ReplrTheme.Color.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(didScreenshot ? "Screenshot taken — open Replr and tap a reply." : "Reply with Replr")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                Text(didScreenshot
                     ? "It drops straight into the box below."
                     : "Long-press 🌐 → pick Replr → screenshot this chat. Your reply lands below.")
                    .font(.system(size: 12))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous).fill(ReplrTheme.Color.surfaceRaised))
        .overlay(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous).stroke(ReplrTheme.Color.glassBorder, lineWidth: 1))
    }

    private var successCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundColor(ReplrTheme.Color.accent)
            Text("That's a Replr reply — you've got it.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ReplrTheme.Color.textPrimary)
            Spacer(minLength: 8)
            Button("Finish →") { onFinish() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.onAccent)
                .padding(.horizontal, 16).frame(height: 38)
                .background(Capsule().fill(ReplrTheme.Color.brandGradient))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous).fill(ReplrTheme.Color.accentSoft))
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message…", text: $draft)
                .focused($focused)
                .font(.system(size: 15))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(ReplrTheme.Color.surface))
                .overlay(Capsule().stroke(ReplrTheme.Color.glassBorder, lineWidth: 1))
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(draft.isEmpty ? ReplrTheme.Color.textTertiary : ReplrTheme.Color.accent)
        }
    }
}

#Preview("Sample demo (live practice)") {
    SampleDemoStep(onFinish: {})
}
