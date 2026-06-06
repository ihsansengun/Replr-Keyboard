import SwiftUI
import PhotosUI
import AppIntents


@main
struct ReplrApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @State private var showCapture = false
    @State private var showSetup = false
    @State private var showPaywall = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        applyBrandAppearance()
        NSLog("[Replr][Shortcuts] App init — calling updateAppShortcutParameters")
        ReplrShortcuts.updateAppShortcutParameters()
        NSLog("[Replr][Shortcuts] updateAppShortcutParameters done — shortcut count: %d", ReplrShortcuts.appShortcuts.count)
    }

    private func applyBrandAppearance() {
        let navBg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.082, green: 0.063, blue: 0.102, alpha: 1) // #15101A
                : UIColor(red: 1.000, green: 0.973, blue: 0.961, alpha: 1) // #FFF8F5 warm white
        }
        let accentColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 1.000, green: 0.435, blue: 0.569, alpha: 1) // #FF6F91 — flirt rose
                : UIColor(red: 0.910, green: 0.267, blue: 0.478, alpha: 1) // #E8447A — deeper rose for light
        }

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = navBg
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor.label]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = accentColor
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
                        case "paywall":
                            showPaywall = true
                        default:
                            break
                        }
                    }
                    .onChange(of: scenePhase) { phase in
                        guard phase == .active else { return }
                        AppGroupService.shared.synchronize()
                        CreditsManager.shared.refreshBalance()
                        if AppGroupService.shared.effectiveCreditBalance == 0 {
                            showPaywall = true
                        }
                        if AppGroupService.shared.autoClearScreenshots {
                            // "After each reply" → clean any single pending shot; otherwise batch at 5.
                            let threshold = AppGroupService.shared.deleteScreenshotAfterEach ? 1 : 5
                            if ScreenshotCleaner.pendingCount() >= threshold {
                                ScreenshotCleaner.clean()
                            }
                        }
                    }
                    .fullScreenCover(isPresented: $showPaywall) {
                        NavigationStack {
                            CreditPacksView(showCloseButton: true)
                        }
                    }
            } else {
                OnboardingView(onComplete: { onboardingComplete = true })
            }
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: TabSelection = .replies

    var body: some View {
        ZStack {
            RepliesView()
                .opacity(selectedTab == .replies ? 1 : 0)
                .allowsHitTesting(selectedTab == .replies)
            MemoryView()
                .opacity(selectedTab == .memory ? 1 : 0)
                .allowsHitTesting(selectedTab == .memory)
            SettingsView()
                .opacity(selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(selectedTab == .settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $selectedTab)
                .ignoresSafeArea(.keyboard) // pin tab bar to screen bottom — keyboard must not push it up
        }
        .task {
            await CreditsManager.shared.load()
        }
        .task {
            await RemoteConfig.refreshShortcutURL()
        }
    }
}

// MARK: - Remote config (backend values swappable without an App Store release)

/// Best-effort fetch of runtime config from the backend. Currently just the Back Tap
/// shortcut install link — so it can be swapped if the iCloud link ever breaks. Failures
/// are silent; the app falls back to the baked-in `Constants.shortcutInstallURL`.
enum RemoteConfig {
    private struct Response: Decodable { let shortcutInstallURL: String? }

    static func refreshShortcutURL() async {
        guard let url = URL(string: Constants.backendURL + "/config") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let link = decoded.shortcutInstallURL, !link.isEmpty else { return }
        AppGroupService.shared.remoteShortcutInstallURL = link
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
                            .foregroundColor(ReplrTheme.Color.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(ReplrTheme.Color.accent)
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
                        .foregroundColor(ReplrTheme.Color.accent)
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
