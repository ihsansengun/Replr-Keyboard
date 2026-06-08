import SwiftUI

/// Intro value-prop carousel — three "show-the-magic" slides with serif headlines.
/// Full-bleed (no progress bar); `onDone` advances into the setup steps.
struct IntroCarouselStep: View {
    let onDone: () -> Void
    @State private var page = 0
    private let count = 3

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDone) {
                        Text("Skip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(ReplrTheme.Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                TabView(selection: $page) {
                    CarouselSlide(illustration: { CaptureReplyArt() },
                                  lead: "Never stare at a ", highlight: "blank reply", trail: ".",
                                  sub: "Screenshot any chat. Replr reads it and writes your reply in seconds.")
                        .tag(0)
                    CarouselSlide(illustration: { ToneArt() },
                                  lead: "Replies in ", highlight: "your tone", trail: ".",
                                  sub: "Pick a vibe once and every reply matches it. Flirty, casual, direct.")
                        .tag(1)
                    CarouselSlide(illustration: { AnyChatArt() },
                                  lead: "Works in ", highlight: "any chat", trail: ".",
                                  sub: "Works in any app. Even on profiles. Just screenshot and Replr handles it.")
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.bottom, 20)

                PrimaryButton(label: page == count - 1 ? "Get started →" : "Next →") {
                    if page < count - 1 { withAnimation { page += 1 } } else { onDone() }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct CarouselSlide<Art: View>: View {
    @ViewBuilder var illustration: () -> Art
    let lead: String
    let highlight: String
    let trail: String
    let sub: String

    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 0)
            illustration().frame(height: 200)
            VStack(spacing: 12) {
                (Text(lead)
                 + Text(highlight).foregroundColor(ReplrTheme.Color.accent)
                 + Text(trail))
                    .font(ReplrTheme.Font.serif(32, weight: .bold))
                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(sub)
                    .font(ReplrTheme.Font.callout)
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Slide illustrations (lightweight SwiftUI, no external assets)

/// A chat bubble with a generated reply chip sliding in — the core "magic".
private struct CaptureReplyArt: View {
    @State private var show = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hey! Are we still on for Friday?")
                .font(.system(size: 14))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(ReplrTheme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold))
                Text("Wouldn't miss it — 7pm?").font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(ReplrTheme.Color.onAccent)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(ReplrTheme.Color.brandGradient))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 14)
        }
        .padding(20)
        .frame(width: 290)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(ReplrTheme.Color.glassBorder, lineWidth: 1))
        .onAppear {
            show = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.35)) { show = true }
        }
    }
}

/// Stacked tone chips with the top one active (brand gradient).
private struct ToneArt: View {
    private let tones = ["Flirty", "Casual", "Professional"]
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(tones.enumerated()), id: \.offset) { i, t in
                Text(t)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(i == 0 ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 22).frame(height: 44)
                    .background(
                        Capsule().fill(i == 0
                            ? AnyShapeStyle(ReplrTheme.Color.brandGradient)
                            : AnyShapeStyle(ReplrTheme.Color.surfaceRaised))
                    )
            }
        }
    }
}

/// A ring of app icons around the Replr mark — "works in any chat".
private struct AnyChatArt: View {
    private let symbols = ["message.fill", "heart.fill", "briefcase.fill", "bubble.left.and.bubble.right.fill"]
    private let positions: [CGSize] = [
        CGSize(width: 0, height: -74), CGSize(width: 74, height: 0),
        CGSize(width: 0, height: 74), CGSize(width: -74, height: 0),
    ]
    var body: some View {
        ZStack {
            ForEach(0..<symbols.count, id: \.self) { i in
                Image(systemName: symbols[i])
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.accent)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(ReplrTheme.Color.surfaceRaised))
                    .overlay(Circle().stroke(ReplrTheme.Color.glassBorder, lineWidth: 1))
                    .offset(positions[i])
            }
            ReplrMark(size: 24)
                .frame(width: 72, height: 72)
                .background(Circle().fill(ReplrTheme.Color.surface))
                .overlay(Circle().stroke(ReplrTheme.Color.accent.opacity(0.4), lineWidth: 1.5))
        }
        .frame(width: 220, height: 200)
    }
}

#Preview("Intro carousel") {
    IntroCarouselStep(onDone: {})
}
