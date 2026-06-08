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
                                  sub: "Hinge, Instagram, iMessage. If you can screenshot it, Replr handles the reply.")
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
                Text("Wouldn't miss it. 7pm?").font(.system(size: 14, weight: .medium))
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

/// Animated tone picker: chips cycle Flirty → Casual → Professional every ~2 s,
/// with a live reply preview card that swaps to show what each tone produces.
private struct ToneArt: View {
    private struct Sample { let tone: String; let reply: String }
    private let samples: [Sample] = [
        Sample(tone: "Flirty",       reply: "Can't stop thinking about you 😏"),
        Sample(tone: "Casual",       reply: "Yeah I'm in. What time? 👍"),
        Sample(tone: "Professional", reply: "I'll have that ready by Friday."),
    ]
    @State private var active = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Horizontal chip row — active chip glows with brand gradient
            HStack(spacing: 10) {
                ForEach(samples.indices, id: \.self) { i in
                    chipView(i)
                }
            }

            Spacer(minLength: 0).frame(maxHeight: 18)

            // Reply preview — all three stacked; only the active one is visible
            ZStack {
                ForEach(samples.indices, id: \.self) { i in
                    bubbleView(i)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_900_000_000)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    active = (active + 1) % samples.count
                }
            }
        }
    }

    private func chipView(_ i: Int) -> some View {
        let on = i == active
        return Text(samples[i].tone)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(on ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                Capsule().fill(on
                    ? AnyShapeStyle(ReplrTheme.Color.brandGradient)
                    : AnyShapeStyle(ReplrTheme.Color.surfaceRaised))
            )
            .overlay(
                Capsule().strokeBorder(on ? Color.clear : ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
            .scaleEffect(on ? 1.05 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: active)
    }

    private func bubbleView(_ i: Int) -> some View {
        let on = i == active
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ReplrTheme.Color.accent)
                .padding(.top, 2)
            Text(samples[i].reply)
                .font(.system(size: 14))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReplrTheme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
        .opacity(on ? 1 : 0)
        .offset(y: on ? 0 : 8)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: active)
    }
}

/// Scattered app-name chips orbiting the Replr logo — "works in any chat".
/// Chips stagger in on appear; the logo pulses gently to anchor the cluster.
private struct AnyChatArt: View {
    private struct Chip { let name: String; let offset: CGSize }
    private let chips: [Chip] = [
        Chip(name: "Hinge",     offset: CGSize(width: -88,  height: -54)),
        Chip(name: "WhatsApp",  offset: CGSize(width: 78,   height: -60)),
        Chip(name: "Instagram", offset: CGSize(width: -100, height: 10)),
        Chip(name: "iMessage",  offset: CGSize(width: 84,   height: 14)),
        Chip(name: "Tinder",    offset: CGSize(width: -66,  height: 74)),
        Chip(name: "Slack",     offset: CGSize(width: 70,   height: 72)),
    ]
    @State private var shown = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            // App name chips
            ForEach(chips.indices, id: \.self) { i in
                Text(chips[i].name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(ReplrTheme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
                    )
                    .offset(chips[i].offset)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.72)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.78).delay(Double(i) * 0.07),
                        value: shown
                    )
            }

            // Replr logo — gentle breathing pulse
            Image("ReplrLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ReplrTheme.Color.accent.opacity(pulse ? 0.6 : 0.2), lineWidth: 1.5)
                )
                .scaleEffect(pulse ? 1.05 : 1.0)
                .shadow(color: ReplrTheme.Color.accent.opacity(0.18), radius: 12, x: 0, y: 0)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            shown = true
            pulse = true
        }
    }
}

#Preview("Intro carousel") {
    IntroCarouselStep(onDone: {})
}
