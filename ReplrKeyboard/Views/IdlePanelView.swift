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
                // Compact: looping demo on the left, caption on the right
                HStack(spacing: 14) {
                    CaptureStepsAnimation()
                        .frame(width: 100, height: 84)

                    Text("Screenshot a chat. Replr reads it and drafts the replies.")
                        .font(.system(size: 14))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 16)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(ReplrTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
            .elevatedSurface(.level1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
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

private let captureStepsLottieJSON = ##"{"nm":"Main Scene","ddd":0,"h":200,"w":240,"meta":{"g":"@lottiefiles/creator@1.94.0"},"layers":[{"ty":4,"nm":"flash","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":33},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[80],"t":39},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":47},{"s":[0],"t":90}]}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":14},"s":{"a":0,"k":[116,166]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[1,1,1]},"r":1,"o":{"a":0,"k":100}}],"ind":1},{"ty":4,"nm":"chips","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[55,55],"t":45},{"s":[100,100],"t":60}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[120,171]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":45},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":58},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[-22,0]},"r":{"a":0,"k":3},"s":{"a":0,"k":[16,6]}},{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 2","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":3},"s":{"a":0,"k":[16,6]}},{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 3","d":1,"p":{"a":0,"k":[22,0]},"r":{"a":0,"k":3},"s":{"a":0,"k":[16,6]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[1,1,1]},"r":1,"o":{"a":0,"k":100}}],"ind":2},{"ty":4,"nm":"keyboard","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,154],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,154],"t":15},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,171],"t":32},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,171],"t":78},{"s":[120,154],"t":90}]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":7},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[104,44],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[104,44],"t":15},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[104,10],"t":32},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[104,10],"t":78},{"s":[104,44],"t":90}]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.0902,0.9176,0.851]},"r":1,"o":{"a":0,"k":100}}],"ind":3},{"ty":4,"nm":"bubbles","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[92,44]},"r":{"a":0,"k":4},"s":{"a":0,"k":[50,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":26}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[150,62]},"r":{"a":0,"k":4},"s":{"a":0,"k":[36,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":44}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[96,80]},"r":{"a":0,"k":4},"s":{"a":0,"k":[54,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":26}}]}],"ind":4},{"ty":4,"nm":"phone","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":60}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":18},"s":{"a":0,"k":[120,170]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}}],"ind":5}],"v":"5.7.0","fr":30,"op":90,"ip":0,"assets":[]}"##
