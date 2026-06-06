import SwiftUI
import Lottie

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel
    @State private var hasClipboardText: Bool = false
    /// Teaching overlay (how-to for steer + Back Tap) behind the sliders button.
    @State private var showTeachingPanel = false
    @State private var teachingPage = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, onOpenSettings: {
                teachingPage = 0
                withAnimation(.easeInOut(duration: 0.18)) { showTeachingPanel = true }
            })
            if model.inputMode == .chat {
                chatContent
            } else {
                emailContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
        .overlay { if showTeachingPanel { teachingPanel } }
    }

    // MARK: - Teaching overlay + cards

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .fill(i == teachingPage ? ReplrTheme.Color.accent
                                            : ReplrTheme.Color.textSecondary.opacity(0.30))
                    .frame(width: i == teachingPage ? 7 : 6, height: i == teachingPage ? 7 : 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: teachingPage)
    }

    /// Compact, centered how-to card: steer (intent) + Back Tap (shortcut). Swipe + ✕ to close.
    private var teachingPanel: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { showTeachingPanel = false } }
            // Card hugs its content (fixed-height slide area) and centers in the keyboard,
            // so it reads as a compact landscape card rather than a near-full-height square.
            VStack(spacing: 10) {
                TabView(selection: $teachingPage) {
                    steerSlide.tag(0)
                    backTapSlide.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 160)

                pageDots
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(
                brandedSurface
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
                    )
            )
            .overlay(alignment: .topLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showTeachingPanel = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(ReplrTheme.Color.surfaceRaised))
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .elevatedSurface(.level1)
            .padding(.horizontal, 16)
        }
        .transition(.opacity)
    }

    /// Slide 1 — the capture flow + the Start CTA (the default landing slide).
    private var captureSlide: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ReplrTheme.Color.accent)
                        .frame(width: 70, height: 70)
                        .blur(radius: 22)
                        .opacity(colorScheme == .dark ? 0.30 : 0.16)
                    CaptureStepsAnimation()
                        .frame(width: 92, height: 78)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drop in your chat")
                        .font(ReplrTheme.Font.serif(18, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Text(AppGroupService.shared.preferredCapture == "backtap"
                         ? "Triple-tap the back of your phone — replies appear right here."
                         : "Tap Start, then screenshot the chat — Replr drafts the replies.")
                        .font(.system(size: 13))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = true }
            } label: {
                HStack(spacing: 6) {
                    Text("Start").font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(ReplrTheme.Color.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .fill(ReplrTheme.Color.brandGradient)
                        .overlay(ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm))
                )
                .shadow(
                    color: colorScheme == .dark ? ReplrTheme.Color.accent.opacity(0.45) : .black.opacity(0.10),
                    radius: colorScheme == .dark ? 14 : 6,
                    x: 0, y: colorScheme == .dark ? 5 : 3
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Slide 2 — Back Tap (opens the app to set it up).
    private var backTapSlide: some View {
        infoSlide(icon: "hand.tap.fill",
                  title: "Reply anywhere",
                  body: "Set up a triple-tap to capture any screen — even dating profiles, where the keyboard can't open.",
                  cta: "Set up Back Tap →",
                  url: "replr://setup")
    }

    /// Slide 3 — Steer (opens the app for the how-to).
    private var steerSlide: some View {
        infoSlide(icon: "text.cursor",
                  title: "Steer the reply",
                  body: "Type your gist first — like \u{201C}ask her to dinner\u{201D} — then tap Start. Replr builds the reply around it.",
                  cta: "Show me how →",
                  url: "replr://tutorial")
    }

    private func infoSlide(icon: String, title: String, body: String,
                           cta: String, url: String) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.accent)
            Text(title)
                .font(ReplrTheme.Font.serif(18, weight: .bold))
                .foregroundColor(ReplrTheme.Color.textPrimary)
            Text(body)
                .font(.system(size: 12))
                .foregroundColor(ReplrTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let dest = URL(string: url) {
                // A SwiftUI Link is the only path that still opens the containing app from a
                // keyboard extension on iOS 18+ (extensionContext.open is a no-op for keyboards,
                // and the selector / responder-chain trick was killed in iOS 18). Full Access required.
                Link(destination: dest) {
                    Text(cta)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.onAccent)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(Capsule().fill(ReplrTheme.Color.brandGradient))
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Soft brand wash over the white surface so cards read on-brand, not flat white.
    private var brandedSurface: some View {
        ZStack {
            ReplrTheme.Color.surface
            LinearGradient(
                colors: [
                    ReplrTheme.Color.accent.opacity(colorScheme == .dark ? 0.13 : 0.09),
                    ReplrTheme.Color.accent.opacity(colorScheme == .dark ? 0.03 : 0.02),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Chat idle

    private var chatContent: some View {
        captureSlide
            .background(brandedSurface)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [ReplrTheme.Color.accent.opacity(0.45), ReplrTheme.Color.glassBorder],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .elevatedSurface(.level1)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Email idle

    private var emailContent: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(ReplrTheme.Color.accent)
                    .frame(width: 92, height: 92)
                    .blur(radius: 30)
                    .opacity(colorScheme == .dark ? 0.28 : 0.14)
                Image(systemName: "envelope.fill")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundColor(ReplrTheme.Color.accent)
            }
            Text("Reply to any email")
                .font(ReplrTheme.Font.serif(20, weight: .bold))
                .foregroundColor(ReplrTheme.Color.textPrimary)

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
                        .fill(hasClipboardText
                              ? AnyShapeStyle(ReplrTheme.Color.brandGradient)
                              : AnyShapeStyle(ReplrTheme.Color.surface))
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
            .animation(.easeInOut(duration: 0.2), value: hasClipboardText)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(brandedSurface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [ReplrTheme.Color.accent.opacity(0.45), ReplrTheme.Color.glassBorder],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .elevatedSurface(.level1)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .onAppear {
            hasClipboardText = UIPasteboard.general.hasStrings
        }
    }
}


// MARK: - Capture steps animation (Lottie, language-agnostic)

/// The live ReplrTheme accent as a Lottie color for the given scheme.
private func replrAccentLottieColor(_ scheme: ColorScheme) -> LottieColor {
    let c = ReplrTheme.Color.accentRGBA(for: scheme)
    return LottieColor(r: c.r, g: c.g, b: c.b, a: c.a)
}

/// Looping Lottie demo of the two capture steps: the keyboard collapses to a
/// slim bar, a screenshot flash fires, then reply chips appear. No words — it
/// reads in any language. Falls back to a static two-step graphic under Reduce
/// Motion (or if the embedded JSON ever fails to parse).
/// Source asset: ReplrKeyboard/Resources/capture_steps.json (embedded below).
private struct CaptureStepsAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Parsed once and cached — the keyboard extension is memory-tight, so we
    /// avoid re-decoding the JSON on every view init.
    private static let animation: LottieAnimation? =
        try? LottieAnimation.from(data: Data(captureStepsLottieJSON.utf8))

    var body: some View {
        if reduceMotion || Self.animation == nil {
            staticFallback
        } else {
            LottieView(animation: Self.animation)
                .configure { $0.backgroundBehavior = .pauseAndRestore }
                .valueProvider(
                    ColorValueProvider(replrAccentLottieColor(colorScheme)),
                    for: AnimationKeypath(keypath: "**.accent.Color"))
                .looping()
                .resizable()
        }
    }

    // Reduce Motion (or parse-failure) fallback: a static two-step graphic.
    private var staticFallback: some View {
        HStack(spacing: 14) {
            staticStep(1, "keyboard.chevron.compact.down")
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ReplrTheme.Color.textTertiary)
            staticStep(2, "camera.viewfinder")
        }
        .frame(maxWidth: .infinity)
    }

    private func staticStep(_ n: Int, _ system: String) -> some View {
        VStack(spacing: 7) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundColor(ReplrTheme.Color.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ReplrTheme.Color.accent))
            Image(systemName: system)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ReplrTheme.Color.accent)
        }
    }
}

private let captureStepsLottieJSON = ##"{"v":"5.7.4","fr":30,"ip":0,"op":90,"w":240,"h":200,"nm":"capture_steps_rich","ddd":0,"assets":[],"layers":[{"ddd":0,"ind":1,"ty":4,"nm":"flash","sr":1,"ks":{"o":{"a":1,"k":[{"t":33,"s":[0],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":38,"s":[85],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":46,"s":[0]}]},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,100,0]},"a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,"shapes":[{"ty":"gr","nm":"g","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[116,166]},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":14}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":100},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":2,"ty":4,"nm":"spark","sr":1,"ks":{"o":{"a":1,"k":[{"t":50,"s":[0],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":58,"s":[100],"i":{"x":[0.6],"y":[1]},"o":{"x":[0.4],"y":[0]}},{"t":72,"s":[0]}]},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,144,0]},"a":{"a":0,"k":[120,144,0]},"s":{"a":1,"k":[{"t":50,"s":[0,0,100],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":60,"s":[120,120,100],"i":{"x":[0.6],"y":[1]},"o":{"x":[0.4],"y":[0]}},{"t":72,"s":[80,80,100]}]}},"ao":0,"shapes":[{"ty":"gr","nm":"x1","it":[{"ty":"rc","nm":"v","d":1,"s":{"a":0,"k":[1.8,11]},"p":{"a":0,"k":[86,150]},"r":{"a":0,"k":0.9}},{"ty":"rc","nm":"h","d":1,"s":{"a":0,"k":[11,1.8]},"p":{"a":0,"k":[86,150]},"r":{"a":0,"k":0.9}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":100},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"x2","it":[{"ty":"rc","nm":"v","d":1,"s":{"a":0,"k":[1.6,8]},"p":{"a":0,"k":[156,146]},"r":{"a":0,"k":0.8}},{"ty":"rc","nm":"h","d":1,"s":{"a":0,"k":[8,1.6]},"p":{"a":0,"k":[156,146]},"r":{"a":0,"k":0.8}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":100},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"x3","it":[{"ty":"rc","nm":"v","d":1,"s":{"a":0,"k":[1.5,7]},"p":{"a":0,"k":[120,137]},"r":{"a":0,"k":0.7}},{"ty":"rc","nm":"h","d":1,"s":{"a":0,"k":[7,1.5]},"p":{"a":0,"k":[120,137]},"r":{"a":0,"k":0.7}},{"ty":"fl","nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"o":{"a":0,"k":100},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":3,"ty":4,"nm":"chips","sr":1,"ks":{"o":{"a":1,"k":[{"t":45,"s":[0],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":56,"s":[100],"i":{"x":[0.6],"y":[1]},"o":{"x":[0.4],"y":[0]}},{"t":80,"s":[100],"i":{"x":[0.6],"y":[1]},"o":{"x":[0.4],"y":[0]}},{"t":88,"s":[0]}]},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,171,0]},"a":{"a":0,"k":[0,0,0]},"s":{"a":1,"k":[{"t":45,"s":[55,55,100],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":58,"s":[100,100,100]}]}},"ao":0,"shapes":[{"ty":"gr","nm":"c1","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[16,6]},"p":{"a":0,"k":[-22,0]},"r":{"a":0,"k":3}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":95},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"c2","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[16,6]},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":3}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":95},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"c3","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[16,6]},"p":{"a":0,"k":[22,0]},"r":{"a":0,"k":3}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":95},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":4,"ty":4,"nm":"keyboard","sr":1,"ks":{"o":{"a":0,"k":100},"r":{"a":0,"k":0},"p":{"a":1,"k":[{"t":0,"s":[120,154,0],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":15,"s":[120,154,0],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":32,"s":[120,171,0],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":78,"s":[120,171,0],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":90,"s":[120,154,0]}]},"a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,"shapes":[{"ty":"gr","nm":"g","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":1,"k":[{"t":0,"s":[104,44],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":15,"s":[104,44],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":32,"s":[104,10],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":78,"s":[104,10],"i":{"x":[0.2],"y":[1]},"o":{"x":[0.2],"y":[0]}},{"t":90,"s":[104,44]}]},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":7}},{"ty":"fl","nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"o":{"a":0,"k":100},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":5,"ty":4,"nm":"bubbles","sr":1,"ks":{"o":{"a":0,"k":100},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,100,0]},"a":{"a":0,"k":[120,100,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,"shapes":[{"ty":"gr","nm":"b1","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[50,9]},"p":{"a":0,"k":[92,44]},"r":{"a":0,"k":4}},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":28},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"b2","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[36,9]},"p":{"a":0,"k":[150,62]},"r":{"a":0,"k":4}},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":46},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"b3","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[54,9]},"p":{"a":0,"k":[96,80]},"r":{"a":0,"k":4}},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":28},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":6,"ty":4,"nm":"phone","sr":1,"ks":{"o":{"a":0,"k":100},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,100,0]},"a":{"a":0,"k":[120,100,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,"shapes":[{"ty":"gr","nm":"outline","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[120,170]},"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":18}},{"ty":"st","nm":"s","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":65},"w":{"a":0,"k":2.5},"lc":2,"lj":2,"ml":4},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"notch","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[34,6]},"p":{"a":0,"k":[120,22]},"r":{"a":0,"k":3}},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":50},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"screen","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[120,170]},"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":18}},{"ty":"fl","nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"o":{"a":0,"k":8},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0}]}"##
