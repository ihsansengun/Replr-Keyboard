import SwiftUI
import Photos

struct OnboardingView: View {
    var onComplete: () -> Void
    @AppStorage("onboardingStep") private var step = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            switch step {
            case 0:
                OnboardingStep(
                    icon: "keyboard",
                    title: "Add Replr Keyboard",
                    description: "Settings → General → Keyboard → Keyboards → Add New Keyboard → Replr",
                    action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        step = 1
                    },
                    buttonLabel: "Open Settings"
                )
            case 1:
                OnboardingStep(
                    icon: "hand.tap",
                    title: "Enable Full Access",
                    description: "In Keyboard settings, enable Full Access for Replr. This lets the keyboard connect to AI.",
                    action: { step = 2 },
                    buttonLabel: "Done"
                )
            case 2:
                PhotosPermissionStep(onNext: { step = 3 })
            case 3:
                BackTapSetupStep(onNext: { step = 4 })
            default:
                OnboardingStep(
                    icon: "checkmark.circle.fill",
                    title: "You're ready",
                    description: "Triple-tap the back of your phone while in any chat. Switch to Replr keyboard and your replies are waiting.",
                    action: {
                        step = 0
                        onComplete()
                    },
                    buttonLabel: "Get Started"
                )
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Photos permission

struct PhotosPermissionStep: View {
    var onNext: () -> Void
    @State private var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)

            Text("Allow Photos Access")
                .font(.title2).bold()

            Text("Replr reads your latest screenshot to generate replies. Your photos are never stored or shared.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if status == .authorized || status == .limited {
                Label("Photos access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                Button("Continue", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else if status == .denied || status == .restricted {
                Text("Permission denied. Open Settings to allow access.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip", action: onNext)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            } else {
                Button("Allow Photos Access") {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                        DispatchQueue.main.async {
                            status = newStatus
                            if newStatus == .authorized || newStatus == .limited {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onNext() }
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

// MARK: - Back Tap setup

struct BackTapSetupStep: View {
    var onNext: () -> Void
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "iphone")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)

            Text("Two quick steps")
                .font(.title2).bold()

            if currentStep == 0 {
                Text("Tap the button to install the Replr shortcut — it takes one tap.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("Add Shortcut") {
                    if let url = URL(string: "https://www.icloud.com/shortcuts/4239b04c8d0d469b905ce6118c5ce706") {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Done — next step") {
                    currentStep = 1
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            } else {
                Text("Open the Settings app on your phone, then follow these steps:")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    SetupRow(number: "1", text: "Accessibility → Touch → Back Tap")
                    SetupRow(number: "2", text: "Triple Tap → Shortcuts → Replr")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Label("First time you triple-tap, iOS will ask to share the screenshot with Replr. Tap \"Allow Always\".", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Done", action: onNext)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
    }

}

struct SetupRow: View {
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

// MARK: - Generic step

struct OnboardingStep: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    let buttonLabel: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
            Text(title).font(.title2).bold()
            Text(description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(buttonLabel, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

// MARK: - BackTap Setup Full View (presented from replr://setup deep link)

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

                    Text("Set up BackTap")
                        .font(.title2.bold())

                    Text("Triple-tapping the back of your iPhone triggers Replr to capture a screenshot and generate replies.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        SetupRow(number: "1", text: "Settings → Accessibility → Touch → Back Tap")
                        SetupRow(number: "2", text: "Tap \"Triple Tap\" (or \"Double Tap\")")
                        SetupRow(number: "3", text: "Scroll down and choose Shortcuts → Replr")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Label("First time you triple-tap, iOS will ask to share the screenshot with Replr. Tap \"Allow Always\".", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
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
            .navigationTitle("BackTap Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}
