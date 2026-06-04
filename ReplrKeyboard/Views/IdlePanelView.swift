import SwiftUI
import Lottie

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel
    @State private var hasClipboardText: Bool = false
    @Environment(\.colorScheme) private var colorScheme

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
        .background(ReplrTheme.Color.bg)
    }

    // MARK: - Chat idle

    private var chatContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                // Language-agnostic looping demo of the 2 steps
                CaptureStepsAnimation()
                    .frame(height: 150)
                    .padding(.top, 14)
                    .padding(.horizontal, 12)

                Text("Screenshot a chat and I'll draft the replies.")
                    .font(.system(size: 13))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)

                // Single, distinct CTA — tapping visibly lowers the keyboard
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("Start")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(ReplrTheme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                            .overlay(ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm))
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? ReplrTheme.Color.accent.opacity(0.45)
                            : .black.opacity(0.10),
                        radius: colorScheme == .dark ? 14 : 6,
                        x: 0, y: colorScheme == .dark ? 5 : 3
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .background(ReplrTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
            .elevatedSurface(.level1)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Email idle

    private var emailContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

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
                        .fill(hasClipboardText ? ReplrTheme.Color.accent : ReplrTheme.Color.surface)
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
            .padding(.top, 10)
            .animation(.easeInOut(duration: 0.2), value: hasClipboardText)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            hasClipboardText = UIPasteboard.general.hasStrings
        }
    }
}


// MARK: - Capture steps animation (Lottie, language-agnostic)

/// Looping Lottie demo of the two capture steps: the keyboard collapses to a
/// slim bar, a screenshot flash fires, then reply chips appear. No words — it
/// reads in any language. Falls back to a static two-step graphic under Reduce
/// Motion (or if the embedded JSON ever fails to parse).
/// Source asset: ReplrKeyboard/Resources/capture_steps.json (embedded below).
private struct CaptureStepsAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

private let captureStepsLottieJSON = ##"{"v":"5.7.4","fr":30,"ip":0,"op":90,"w":240,"h":200,"nm":"capture_steps","ddd":0,"assets":[],"layers":[{"ddd":0,"ind":1,"ty":4,"nm":"flash","sr":1,"ks":{"o":{"a":1,"k":[{"t":33,"s":[0],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":39,"s":[78],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":47,"s":[0]}]},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,100,0]},"a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,"shapes":[{"ty":"gr","nm":"flashG","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[116,166]},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":14}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":100},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":2,"ty":4,"nm":"chips","sr":1,"ks":{"o":{"a":1,"k":[{"t":45,"s":[0],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":58,"s":[100],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":80,"s":[100],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":88,"s":[0]}]},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,171,0]},"a":{"a":0,"k":[0,0,0]},"s":{"a":1,"k":[{"t":45,"s":[55,55,100],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":60,"s":[100,100,100]}]}},"ao":0,"shapes":[{"ty":"gr","nm":"chipL","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[16,6]},"p":{"a":0,"k":[-22,0]},"r":{"a":0,"k":3}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":95},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"chipM","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[16,6]},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":3}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":95},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"chipR","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[16,6]},"p":{"a":0,"k":[22,0]},"r":{"a":0,"k":3}},{"ty":"fl","nm":"f","c":{"a":0,"k":[1,1,1]},"o":{"a":0,"k":95},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":3,"ty":4,"nm":"keyboard","sr":1,"ks":{"o":{"a":0,"k":100},"r":{"a":0,"k":0},"p":{"a":1,"k":[{"t":0,"s":[120,154,0],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":15,"s":[120,154,0],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":32,"s":[120,171,0],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":78,"s":[120,171,0],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":90,"s":[120,154,0]}]},"a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,"shapes":[{"ty":"gr","nm":"kbG","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":1,"k":[{"t":0,"s":[104,44],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":15,"s":[104,44],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":32,"s":[104,10],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":78,"s":[104,10],"i":{"x":[0.66],"y":[1]},"o":{"x":[0.34],"y":[0]}},{"t":90,"s":[104,44]}]},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":7}},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.09,0.918,0.851]},"o":{"a":0,"k":92},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":4,"ty":4,"nm":"bubbles","sr":1,"ks":{"o":{"a":0,"k":100},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,100,0]},"a":{"a":0,"k":[120,100,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,"shapes":[{"ty":"gr","nm":"b1","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[50,9]},"p":{"a":0,"k":[92,44]},"r":{"a":0,"k":4}},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":26},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"b2","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[36,9]},"p":{"a":0,"k":[150,62]},"r":{"a":0,"k":4}},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":44},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","nm":"b3","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[54,9]},"p":{"a":0,"k":[96,80]},"r":{"a":0,"k":4}},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":26},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0},{"ddd":0,"ind":5,"ty":4,"nm":"phone","sr":1,"ks":{"o":{"a":0,"k":100},"r":{"a":0,"k":0},"p":{"a":0,"k":[120,100,0]},"a":{"a":0,"k":[120,100,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,"shapes":[{"ty":"gr","nm":"phoneG","it":[{"ty":"rc","nm":"r","d":1,"s":{"a":0,"k":[120,170]},"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":18}},{"ty":"st","nm":"s","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":60},"w":{"a":0,"k":2.5},"lc":2,"lj":2,"ml":4},{"ty":"fl","nm":"f","c":{"a":0,"k":[0.5,0.55,0.62]},"o":{"a":0,"k":6},"r":1},{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ip":0,"op":90,"st":0,"bm":0}]}"##
