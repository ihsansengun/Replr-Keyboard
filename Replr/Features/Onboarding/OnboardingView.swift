import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var step = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            switch step {
            case 0: OnboardingStep(
                icon: "keyboard",
                title: "Add Replr Keyboard",
                body: "Go to Settings → General → Keyboard → Keyboards → Add New Keyboard → Replr",
                action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    step = 1
                },
                buttonLabel: "Open Settings"
            )
            case 1: OnboardingStep(
                icon: "hand.tap",
                title: "Enable Full Access",
                body: "In Keyboard settings, enable Full Access for Replr. This lets the keyboard connect to AI.",
                action: { step = 2 },
                buttonLabel: "Done"
            )
            case 2: OnboardingStep(
                icon: "camera.metering.center.weighted",
                title: "Allow Screen Capture",
                body: "Replr captures one screenshot when you tap the camera. Nothing is saved or stored — the image goes directly to AI.",
                action: { step = 3 },
                buttonLabel: "Got it"
            )
            default: OnboardingStep(
                icon: "checkmark.circle.fill",
                title: "You're ready",
                body: "Switch to Replr in any conversation, tap the camera, and get replies.",
                action: onComplete,
                buttonLabel: "Get Started"
            )
            }
            Spacer()
        }
        .padding()
    }
}

struct OnboardingStep: View {
    let icon: String
    let title: String
    let body: String
    let action: () -> Void
    let buttonLabel: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.accent)
            Text(title).font(.title2).bold()
            Text(body).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(buttonLabel, action: action).buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}
