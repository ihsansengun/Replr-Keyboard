import SwiftUI
import Photos

// MARK: - Palette

private enum OBColors {
    static let accent   = Color(red: 0.831, green: 0.627, blue: 0.090) // #D4A017 mustard
    static let cream    = Color(red: 0.929, green: 0.898, blue: 0.816) // #EDE5D0
    static let taupe    = Color(red: 0.420, green: 0.376, blue: 0.314) // #6B6050
    static let dotOff   = Color(red: 0.180, green: 0.145, blue: 0.094) // #2E2518
    static let bg0      = Color(red: 0.118, green: 0.086, blue: 0.031) // #1E1608
    static let bg1      = Color(red: 0.059, green: 0.047, blue: 0.020) // #0F0C05
    static let accentFg = Color(red: 0.059, green: 0.047, blue: 0.020) // #0F0C05
}

// MARK: - Shared wrapper

private struct DarkOnboardingScreen<Icon: View, CTA: View>: View {
    let stepLabel: String   // "STEP 1 OF 5" or "READY"
    let currentStep: Int    // 1-based; drives progress dot highlight
    let headline: String
    let bodyText: String    // Renamed from `body` to avoid conflict with View's computed `body` property
    let glowSize: CGFloat   // 80 for steps 1-4, 120 for done
    var onBack: (() -> Void)? = nil
    @ViewBuilder var icon: () -> Icon
    @ViewBuilder var cta: () -> CTA

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(OBColors.taupe)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 28)
                    } else {
                        Color.clear.frame(width: 28)
                    }

                    Spacer()

                    Text(stepLabel)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1)
                        .foregroundColor(
                            currentStep == totalSteps
                                ? OBColors.accent.opacity(0.56)
                                : OBColors.taupe
                        )

                    Spacer()
                    Color.clear.frame(width: 28)
                }
                .padding(.top, 72)
                .padding(.horizontal, 24)

                Spacer().frame(maxHeight: 80)

                ZStack {
                    RadialGradient(
                        colors: [OBColors.accent.opacity(currentStep == totalSteps ? 0.22 : 0.16), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowSize / 2
                    )
                    .frame(width: glowSize, height: glowSize)

                    icon()
                }
                .padding(.bottom, 32)

                Text(headline)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(OBColors.cream)
                    .multilineTextAlignment(.center)
                    .tracking(-0.3)
                    .padding(.horizontal, 40)

                Text(bodyText)
                    .font(.system(size: 13))
                    .foregroundColor(OBColors.taupe)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 12)
                    .padding(.horizontal, 40)

                Spacer()

                VStack(spacing: 16) {
                    cta()

                    HStack(spacing: 7) {
                        ForEach(1...totalSteps, id: \.self) { i in
                            Circle()
                                .fill(i == currentStep ? OBColors.accent : OBColors.dotOff)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [OBColors.bg0, OBColors.bg1],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Button styles

private struct GhostCTAButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(OBColors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(OBColors.accent.opacity(0.55), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SolidCTAButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(OBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(OBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icons (Canvas-drawn, stroke-based)

private struct KeyboardIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var body_ = Path()
            body_.addRoundedRect(
                in: CGRect(x: w*0.08, y: h*0.25, width: w*0.84, height: h*0.50),
                cornerSize: CGSize(width: 4, height: 4)
            )
            ctx.stroke(body_, with: .color(OBColors.accent),
                       style: StrokeStyle(lineWidth: 1.5))
            let kw = w * 0.09, kh = h * 0.14
            var keys = Path()
            let y1 = h * 0.34, y2 = h * 0.52
            for i in 0..<4 {
                let x = w * 0.14 + CGFloat(i) * (kw + w * 0.065)
                keys.addRoundedRect(in: CGRect(x: x, y: y1, width: kw, height: kh),
                                    cornerSize: CGSize(width: 1.5, height: 1.5))
            }
            keys.addRoundedRect(in: CGRect(x: w*0.24, y: y2, width: w*0.52, height: kh),
                                cornerSize: CGSize(width: 1.5, height: 1.5))
            ctx.fill(keys, with: .color(OBColors.accent.opacity(0.45)))
        }
        .frame(width: 52, height: 52)
    }
}

private struct LockIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var body_ = Path()
            body_.addRoundedRect(
                in: CGRect(x: w*0.22, y: h*0.44, width: w*0.56, height: h*0.42),
                cornerSize: CGSize(width: 4, height: 4)
            )
            ctx.stroke(body_, with: .color(OBColors.accent),
                       style: StrokeStyle(lineWidth: 1.5))
            var shackle = Path()
            shackle.move(to: CGPoint(x: w*0.30, y: h*0.45))
            shackle.addLine(to: CGPoint(x: w*0.30, y: h*0.28))
            shackle.addArc(center: CGPoint(x: w*0.50, y: h*0.28),
                           radius: w*0.20,
                           startAngle: .degrees(180), endAngle: .degrees(0),
                           clockwise: false)
            shackle.addLine(to: CGPoint(x: w*0.70, y: h*0.45))
            ctx.stroke(shackle, with: .color(OBColors.accent),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            var dot = Path()
            dot.addEllipse(in: CGRect(x: w*0.44, y: h*0.60, width: w*0.12, height: h*0.12))
            ctx.fill(dot, with: .color(OBColors.accent.opacity(0.65)))
        }
        .frame(width: 52, height: 52)
    }
}

private struct PaperPlaneIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var path = Path()
            path.move(to: CGPoint(x: w*0.88, y: h*0.12))
            path.addLine(to: CGPoint(x: w*0.06, y: h*0.54))
            path.addLine(to: CGPoint(x: w*0.38, y: h*0.62))
            path.addLine(to: CGPoint(x: w*0.52, y: h*0.88))
            path.addLine(to: CGPoint(x: w*0.88, y: h*0.12))
            path.move(to: CGPoint(x: w*0.38, y: h*0.62))
            path.addLine(to: CGPoint(x: w*0.65, y: h*0.43))
            ctx.stroke(path, with: .color(OBColors.accent),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 52, height: 52)
    }
}

private struct BullseyeIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w/2, cy = h/2
            var rings = Path()
            rings.addEllipse(in: CGRect(x: cx-w*0.44, y: cy-h*0.44, width: w*0.88, height: h*0.88))
            rings.addEllipse(in: CGRect(x: cx-w*0.27, y: cy-h*0.27, width: w*0.54, height: h*0.54))
            ctx.stroke(rings, with: .color(OBColors.accent),
                       style: StrokeStyle(lineWidth: 1.4))
            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx-w*0.10, y: cy-h*0.10, width: w*0.20, height: h*0.20))
            ctx.fill(dot, with: .color(OBColors.accent.opacity(0.70)))
        }
        .frame(width: 52, height: 52)
    }
}

private struct BullseyeDoneIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w/2, cy = h/2
            var outer = Path()
            outer.addEllipse(in: CGRect(x: cx-w*0.46, y: cy-h*0.46, width: w*0.92, height: h*0.92))
            ctx.stroke(outer, with: .color(OBColors.accent.opacity(0.30)),
                       style: StrokeStyle(lineWidth: 1.2))
            var mid = Path()
            mid.addEllipse(in: CGRect(x: cx-w*0.33, y: cy-h*0.33, width: w*0.66, height: h*0.66))
            ctx.stroke(mid, with: .color(OBColors.accent.opacity(0.60)),
                       style: StrokeStyle(lineWidth: 1.3))
            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx-w*0.19, y: cy-h*0.19, width: w*0.38, height: h*0.38))
            ctx.stroke(inner, with: .color(OBColors.accent),
                       style: StrokeStyle(lineWidth: 1.5))
            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx-w*0.075, y: cy-h*0.075, width: w*0.15, height: h*0.15))
            ctx.fill(dot, with: .color(OBColors.accent))
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: - Step views

private struct AddKeyboardStep: View {
    let onNext: () -> Void

    var body: some View {
        DarkOnboardingScreen(
            stepLabel: "STEP 1 OF 5",
            currentStep: 1,
            headline: "Add the Replr\nkeyboard",
            bodyText: "Settings → General → Keyboards → Add New",
            glowSize: 80
        ) {
            KeyboardIcon()
        } cta: {
            GhostCTAButton(label: "Open Settings →") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                onNext()
            }
        }
    }
}

private struct FullAccessStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        DarkOnboardingScreen(
            stepLabel: "STEP 2 OF 5",
            currentStep: 2,
            headline: "Enable Full\nAccess",
            bodyText: "Lets the keyboard connect to AI.",
            glowSize: 80,
            onBack: onBack
        ) {
            LockIcon()
        } cta: {
            GhostCTAButton(label: "Done →", action: onNext)
        }
    }
}

private struct PhotosPermissionStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        DarkOnboardingScreen(
            stepLabel: "STEP 3 OF 5",
            currentStep: 3,
            headline: "Allow photos",
            bodyText: "Replr reads your latest screenshot.\nNothing is stored.",
            glowSize: 80,
            onBack: onBack
        ) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(OBColors.accent)
        } cta: {
            if status == .authorized || status == .limited {
                GhostCTAButton(label: "Continue →", action: onNext)
            } else if status == .denied || status == .restricted {
                VStack(spacing: 10) {
                    GhostCTAButton(label: "Open Settings →") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Skip", action: onNext)
                        .font(.system(size: 13))
                        .foregroundColor(OBColors.taupe)
                        .buttonStyle(.plain)
                }
            } else {
                GhostCTAButton(label: "Allow Photos →") {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                        DispatchQueue.main.async {
                            status = newStatus
                            if newStatus == .authorized || newStatus == .limited {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onNext() }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct BackTapSetupStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var subStep = 0  // 0 = add shortcut, 1 = configure settings

    var body: some View {
        DarkOnboardingScreen(
            stepLabel: "STEP 4 OF 5",
            currentStep: 4,
            headline: "Set up\ndouble tap",
            bodyText: subStep == 0
                ? "First, install the Replr shortcut with one tap."
                : "① Accessibility → Touch → Back Tap\n② Double Tap → Replr",
            glowSize: 80,
            onBack: onBack
        ) {
            BullseyeIcon()
        } cta: {
            if subStep == 0 {
                VStack(spacing: 10) {
                    GhostCTAButton(label: "Add Shortcut →") {
                        if let url = URL(string: "https://www.icloud.com/shortcuts/4239b04c8d0d469b905ce6118c5ce706") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Done — next step") { subStep = 1 }
                        .font(.system(size: 13))
                        .foregroundColor(OBColors.taupe)
                        .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 10) {
                    GhostCTAButton(label: "Open Settings →") {
                        if let url = URL(string: "prefs:root=ACCESSIBILITY") {
                            UIApplication.shared.open(url, options: [:]) { success in
                                if !success, let fallback = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(fallback)
                                }
                            }
                        }
                    }
                    Button("Done →", action: onNext)
                        .font(.system(size: 13))
                        .foregroundColor(OBColors.taupe)
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DoneStep: View {
    let onComplete: () -> Void
    let onBack: () -> Void

    var body: some View {
        DarkOnboardingScreen(
            stepLabel: "READY",
            currentStep: 5,
            headline: "You're in.",
            bodyText: "Double-tap the back of your phone while\nin any chat. Switch to Replr. Pick a reply.",
            glowSize: 120,
            onBack: onBack
        ) {
            BullseyeDoneIcon()
        } cta: {
            SolidCTAButton(label: "Start Replr", action: onComplete)
        }
    }
}

// MARK: - Root coordinator

struct OnboardingView: View {
    var onComplete: () -> Void
    @AppStorage("onboardingStep") private var step = 0

    var body: some View {
        switch step {
        case 0: AddKeyboardStep(onNext: { step = 1 })
        case 1: FullAccessStep(onNext: { step = 2 }, onBack: { step = 0 })
        case 2: PhotosPermissionStep(onNext: { step = 3 }, onBack: { step = 1 })
        case 3: BackTapSetupStep(onNext: { step = 4 }, onBack: { step = 2 })
        case 4: DoneStep(onComplete: { step = 0; onComplete() }, onBack: { step = 3 })
        default: AddKeyboardStep(onNext: { step = 1 })
        }
    }
}

// MARK: - SetupRow helper (used by BackTapSetupFullView)

private struct SetupRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - BackTapSetupFullView (deep-link sheet from replr://setup)

struct BackTapSetupFullView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 16)

                    Text("Set up Back Tap")
                        .font(.title2.bold())

                    Text("Double-tapping the back of your iPhone triggers Replr to capture a screenshot and generate replies.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        SetupRow(number: "1", text: "Settings → Accessibility → Touch → Back Tap")
                        SetupRow(number: "2", text: "Tap \"Double Tap\"")
                        SetupRow(number: "3", text: "Scroll down and choose Shortcuts → Replr")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Label("First time you double-tap, iOS will ask to share the screenshot with Replr. Tap \"Allow Always\".", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        if let url = URL(string: "prefs:root=ACCESSIBILITY") {
                            UIApplication.shared.open(url, options: [:]) { success in
                                if !success, let fallback = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(fallback)
                                }
                            }
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)

                    Spacer(minLength: 24)
                }
            }
            .navigationTitle("Set up Back Tap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}
