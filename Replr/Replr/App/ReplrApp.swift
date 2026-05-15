import SwiftUI
import PhotosUI
import AppIntents

@main
struct ReplrApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @State private var showCapture = false
    @State private var showSetup = false

    init() {
        NSLog("[Replr][Shortcuts] App init — calling updateAppShortcutParameters")
        ReplrShortcuts.updateAppShortcutParameters()
        NSLog("[Replr][Shortcuts] updateAppShortcutParameters done — shortcut count: %d", ReplrShortcuts.appShortcuts.count)
    }

    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                ContentView()
                    .fullScreenCover(isPresented: $showCapture) {
                        CaptureView(isPresented: $showCapture)
                    }
                    .sheet(isPresented: $showSetup) {
                        BackTapSetupFullView(isPresented: $showSetup)
                    }
                    .onOpenURL { url in
                        guard url.scheme == "replr" else { return }
                        switch url.host {
                        case "capture":
                            showCapture = true
                        case "setup":
                            showSetup = true
                        default:
                            break
                        }
                    }
            } else {
                OnboardingView(onComplete: { onboardingComplete = true })
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            CaptureLogView()
                .tabItem { Label("Captures", systemImage: "camera.viewfinder") }
            SummariesView()
                .tabItem { Label("Memory", systemImage: "brain") }
            TonesView()
                .tabItem { Label("Tones", systemImage: "slider.horizontal.3") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Color(red: 0.961, green: 0.651, blue: 0.137))
        .task {
            let txID = await SubscriptionManager.shared.currentTransactionID()
            UserDefaults(suiteName: Constants.appGroupID)?.set(txID, forKey: "transaction_id")
        }
    }
}

// MARK: - Capture Flow (fallback when keyboard can't present picker directly)

struct CaptureView: View {
    @Binding var isPresented: Bool
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var status: CaptureStatus = .idle

    enum CaptureStatus { case idle, processing, done }

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                switch status {
                case .idle:
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                        Text("Pick your screenshot")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Select the chat screenshot to\ngenerate replies in your keyboard.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }

                    PhotosPicker(
                        selection: $pickerItem,
                        matching: {
                            if #available(iOS 16, *) { return .screenshots }
                            return .images
                        }()
                    ) {
                        Text("Choose Screenshot")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)
                    .onChange(of: pickerItem) { item in
                        guard let item else { return }
                        status = .processing
                        Task { await process(item) }
                    }

                case .processing:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Processing…")
                        .foregroundColor(.white.opacity(0.7))

                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.green)
                    Text("Done! Switch back to your keyboard.")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if status != .processing {
                    Button(status == .done ? "Close" : "Cancel") { isPresented = false }
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 32)
                }
            }
        }
    }

    private func process(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            await MainActor.run { status = .idle }
            return
        }
        do {
            try AppGroupService.shared.writeScreenshot(image)
            AppGroupService.shared.isCaptureReady = true
            await MainActor.run { status = .done }
        } catch {
            await MainActor.run { status = .idle }
        }
    }
}
