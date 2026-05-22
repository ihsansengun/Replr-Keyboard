import SwiftUI
import Photos

// MARK: - Shared wrapper

private struct DarkOnboardingScreen<Icon: View, CTA: View>: View {
    let stepLabel: String
    let currentStep: Int    // 1-based; drives progress dot highlight
    let headline: String
    let bodyText: String    // Renamed from `body` to avoid conflict with View's computed `body` property
    let glowSize: CGFloat   // 80 for steps 1-4, 120 for done
    var onBack: (() -> Void)? = nil
    @ViewBuilder var icon: () -> Icon
    @ViewBuilder var cta: () -> CTA

    private let totalSteps = 6

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28)
                } else {
                    Color.clear.frame(width: 28)
                }

                Spacer()

                Text(stepLabel)
                    .font(ReplrTheme.Font.overline)
                    .tracking(1.5)
                    .foregroundColor(
                        currentStep == totalSteps
                            ? ReplrTheme.Color.accent.opacity(0.56)
                            : ReplrTheme.Color.textSecondary
                    )

                Spacer()
                Color.clear.frame(width: 28)
            }
            .padding(.top, 72)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 0) {
                ZStack {
                    RadialGradient(
                        colors: [ReplrTheme.Color.accent.opacity(currentStep == totalSteps ? 0.22 : 0.16), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowSize / 2
                    )
                    .frame(width: glowSize, height: glowSize)

                    icon()
                }
                .padding(.bottom, 32)

                Text(headline)
                    .font(ReplrTheme.Font.heading).tracking(-0.2)
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text(bodyText)
                    .font(ReplrTheme.Font.footnote)
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 12)
                    .padding(.horizontal, 40)

                VStack(spacing: 0) {
                    cta()
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
            }

            Spacer()

            HStack(spacing: 7) {
                ForEach(1...totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == currentStep ? ReplrTheme.Color.accent : ReplrTheme.Color.border)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
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
            ctx.stroke(body_, with: .color(ReplrTheme.Color.accent),
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
            ctx.fill(keys, with: .color(ReplrTheme.Color.accent.opacity(0.45)))
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
            ctx.stroke(body_, with: .color(ReplrTheme.Color.accent),
                       style: StrokeStyle(lineWidth: 1.5))
            var shackle = Path()
            shackle.move(to: CGPoint(x: w*0.30, y: h*0.45))
            shackle.addLine(to: CGPoint(x: w*0.30, y: h*0.28))
            shackle.addArc(center: CGPoint(x: w*0.50, y: h*0.28),
                           radius: w*0.20,
                           startAngle: .degrees(180), endAngle: .degrees(0),
                           clockwise: false)
            shackle.addLine(to: CGPoint(x: w*0.70, y: h*0.45))
            ctx.stroke(shackle, with: .color(ReplrTheme.Color.accent),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            var dot = Path()
            dot.addEllipse(in: CGRect(x: w*0.44, y: h*0.60, width: w*0.12, height: h*0.12))
            ctx.fill(dot, with: .color(ReplrTheme.Color.accent.opacity(0.65)))
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
            ctx.stroke(path, with: .color(ReplrTheme.Color.accent),
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
            ctx.stroke(rings, with: .color(ReplrTheme.Color.accent),
                       style: StrokeStyle(lineWidth: 1.4))
            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx-w*0.10, y: cy-h*0.10, width: w*0.20, height: h*0.20))
            ctx.fill(dot, with: .color(ReplrTheme.Color.accent.opacity(0.70)))
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
            ctx.stroke(outer, with: .color(ReplrTheme.Color.accent.opacity(0.30)),
                       style: StrokeStyle(lineWidth: 1.2))
            var mid = Path()
            mid.addEllipse(in: CGRect(x: cx-w*0.33, y: cy-h*0.33, width: w*0.66, height: h*0.66))
            ctx.stroke(mid, with: .color(ReplrTheme.Color.accent.opacity(0.60)),
                       style: StrokeStyle(lineWidth: 1.3))
            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx-w*0.19, y: cy-h*0.19, width: w*0.38, height: h*0.38))
            ctx.stroke(inner, with: .color(ReplrTheme.Color.accent),
                       style: StrokeStyle(lineWidth: 1.5))
            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx-w*0.075, y: cy-h*0.075, width: w*0.15, height: h*0.15))
            ctx.fill(dot, with: .color(ReplrTheme.Color.accent))
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: - Step views

private struct AddKeyboardStep: View {
    let onNext: () -> Void

    var body: some View {
        DarkOnboardingScreen(
            stepLabel: "STEP 1 OF 6",
            currentStep: 1,
            headline: "Add the Replr\nkeyboard",
            bodyText: "Settings → General → Keyboards → Add New",
            glowSize: 80
        ) {
            KeyboardIcon()
        } cta: {
            PrimaryButton(label: "Open Settings →") {
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
            stepLabel: "STEP 2 OF 6",
            currentStep: 2,
            headline: "Enable Full\nAccess",
            bodyText: "Lets the keyboard connect to AI.",
            glowSize: 80,
            onBack: onBack
        ) {
            LockIcon()
        } cta: {
            VStack(spacing: 10) {
                PrimaryButton(label: "Open Settings →") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Done →", action: onNext)
            }
        }
    }
}

private struct PhotosPermissionStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        DarkOnboardingScreen(
            stepLabel: "STEP 3 OF 6",
            currentStep: 3,
            headline: "Allow photos",
            bodyText: "Replr reads your latest screenshot.\nNothing is stored.",
            glowSize: 80,
            onBack: onBack
        ) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(ReplrTheme.Color.accent)
        } cta: {
            if status == .authorized || status == .limited {
                PrimaryButton(label: "Continue →", action: onNext)
            } else if status == .denied || status == .restricted {
                VStack(spacing: 10) {
                    PrimaryButton(label: "Open Settings →") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    TertiaryButton(label: "Skip", action: onNext)
                }
            } else {
                PrimaryButton(label: "Allow Photos →") {
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
            stepLabel: subStep == 0 ? "STEP 4 OF 6" : "STEP 5 OF 6",
            currentStep: subStep == 0 ? 4 : 5,
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
                    PrimaryButton(label: "Add Shortcut →") {
                        if let url = URL(string: "https://www.icloud.com/shortcuts/4239b04c8d0d469b905ce6118c5ce706") {
                            UIApplication.shared.open(url)
                        }
                    }
                    TertiaryButton(label: "Done — next step") { subStep = 1 }
                }
            } else {
                VStack(spacing: 10) {
                    PrimaryButton(label: "Open Settings →") {
                        if let url = URL(string: "prefs:root=ACCESSIBILITY") {
                            UIApplication.shared.open(url, options: [:]) { success in
                                if !success, let fallback = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(fallback)
                                }
                            }
                        }
                    }
                    TertiaryButton(label: "Done →", action: onNext)
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
            currentStep: 6,
            headline: "You're in.",
            bodyText: "Double-tap the back of your phone while\nin any chat. Switch to Replr. Pick a reply.",
            glowSize: 120,
            onBack: onBack
        ) {
            BullseyeDoneIcon()
        } cta: {
            PrimaryButton(label: "Start Replr", action: onComplete)
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
