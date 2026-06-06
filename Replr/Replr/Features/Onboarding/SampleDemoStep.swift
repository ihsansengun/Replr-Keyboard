import SwiftUI

/// The first-win finale: a built-in demo. A canned chat → tap to generate → replies animate in.
/// No network, no credits — purely illustrative. "Finish" completes onboarding.
struct SampleDemoStep: View {
    let onFinish: () -> Void
    @State private var phase: Phase = .idle
    private enum Phase { case idle, generating, done }

    private let incoming = "So… are you free this weekend? 👀"
    private let replies = [
        "Depends — are you asking me out? 😏",
        "I might be. What did you have in mind?",
        "For you, I'll make time this weekend.",
    ]

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.accent)
                    (Text("See it ")
                     + Text("in action").foregroundColor(ReplrTheme.Color.accent)
                     + Text("."))
                        .font(ReplrTheme.Font.serif(30, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                demoCard
                    .padding(.horizontal, 24)

                Spacer()

                Group {
                    switch phase {
                    case .idle:
                        PrimaryButton(label: "Generate replies ✨") {
                            withAnimation { phase = .generating }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { phase = .done }
                            }
                        }
                    case .generating:
                        PrimaryButton(label: "Generating…", action: {})
                            .disabled(true)
                            .opacity(0.6)
                    case .done:
                        PrimaryButton(label: "Finish →", action: onFinish)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(incoming)
                .font(.system(size: 15))
                .foregroundColor(ReplrTheme.Color.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(ReplrTheme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)

            switch phase {
            case .idle:
                Text("Tap below — Replr drafts your replies.")
                    .font(.system(size: 13))
                    .foregroundColor(ReplrTheme.Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .generating:
                HStack(spacing: 8) {
                    ProgressView().tint(ReplrTheme.Color.accent)
                    Text("Reading the chat…")
                        .font(.system(size: 13))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .done:
                VStack(spacing: 8) {
                    ForEach(Array(replies.enumerated()), id: \.offset) { _, r in
                        Text(r)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ReplrTheme.Color.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(ReplrTheme.Color.accent.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(18)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(ReplrTheme.Color.glassBorder, lineWidth: 1))
    }
}

#Preview("Sample demo") {
    SampleDemoStep(onFinish: {})
}
