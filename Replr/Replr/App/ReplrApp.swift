import SwiftUI
import AppIntents


@main
struct ReplrApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @AppStorage(Constants.colorSchemeAppearanceKey) private var colorSchemeAppearance = "system"
    @StateObject private var authService = AuthService.shared
    @State private var signedIn: Bool = AuthService.shared.isSignedIn
    @State private var showSetup = false
    @State private var showPaywall = false
    @State private var showTutorial = false
    @State private var tutorialTopic: String? = nil
    @State private var showTones = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Make Fraunces available to both the app and the keyboard extension: copy it into the
        // shared App Group container (the keyboard can't read the app bundle), then register it.
        AppGroupService.shared.installSerifFontIfNeeded()
        AppGroupService.shared.registerSerifFont()
        // Run the free-credit grant at launch (not lazily on first ContentView, which is
        // post-onboarding) so new users have their starting credits during onboarding and
        // first use. CreditsManager.migrateIfNeeded() is idempotent.
        _ = CreditsManager.shared
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

    private var resolvedScheme: ColorScheme? {
        switch colorSchemeAppearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // nil = follow iOS system setting (the default)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !signedIn {
                    SignInView(onSuccess: { signedIn = true })
                        .environmentObject(authService)
                } else if !onboardingComplete {
                    OnboardingView(onComplete: { onboardingComplete = true })
                } else {
                    ContentView()
                        .sheet(isPresented: $showSetup) {
                            BackTapSetupFullView(isPresented: $showSetup)
                        }
                        .sheet(isPresented: $showTutorial) {
                            UsageTutorialView(startTopic: tutorialTopic, onDone: { showTutorial = false })
                        }
                        .sheet(isPresented: $showTones) {
                            TonesView()   // self-contained (own NavigationStack + VM)
                        }
                        .onOpenURL { url in
                            guard url.scheme == "replr" else { return }
                            switch url.host {
                            case "setup":
                                showSetup = true
                            case "tutorial":
                                // e.g. replr://tutorial/steer opens directly at the Steer step.
                                tutorialTopic = url.path.isEmpty ? nil : url.lastPathComponent
                                showTutorial = true
                            case "paywall":
                                showPaywall = true
                            case "tones":
                                // Keyboard teaching panel: "Browse all tones →"
                                showTones = true
                            case "fullaccess":
                                // The keyboard can't open the Settings app itself
                                // (app-settings: is ignored from extensions), so the
                                // limited-Photos card deep-links here and the app
                                // bounces on. Slight delay: an open() fired before the
                                // scene is fully active (cold launch) is silently dropped.
                                if let settings = URL(string: UIApplication.openSettingsURLString) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        UIApplication.shared.open(settings)
                                    }
                                }
                            default:
                                break
                            }
                        }
                        .onChange(of: scenePhase) { phase in
                            guard phase == .active else { return }
                            AppGroupService.shared.synchronize()
                            CreditsManager.shared.refreshBalance()
                            Task {
                                // Adopt the legacy local balance into the server ledger once,
                                // then mirror the authoritative server balance into the App Group.
                                await CreditsManager.shared.serverMigrateIfNeeded()
                                await CreditsManager.shared.syncServerBalance()
                            }
                            AppGroupService.shared.deleteStaleScreenshot()
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
                        .onChange(of: authService.isSignedIn) { newValue in
                            if !newValue { signedIn = false }
                        }
                }
            }
            .preferredColorScheme(resolvedScheme)
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: TabSelection = .replies

    var body: some View {
        ZStack {
            HistoryView()
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
            // Variant first so the product list loads in the served order.
            await PaywallService.refresh()
            await CreditsManager.shared.load()
        }
        .task {
            await RemoteConfig.refresh()
        }
    }
}

// MARK: - Remote config (backend values swappable without an App Store release)

/// Best-effort fetch of runtime config from the backend: the Back Tap shortcut
/// install link and the model catalog (ids/labels/credit costs). Both are cached
/// in the App Group; failures are silent and the app falls back to baked-in values.
enum RemoteConfig {
    private struct Response: Decodable {
        let shortcutInstallURL: String?
        let models: [RemoteModelInfo]?
    }

    static func refresh() async {
        guard let url = URL(string: Constants.backendURL + "/config") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return }
        if let link = decoded.shortcutInstallURL, !link.isEmpty {
            AppGroupService.shared.remoteShortcutInstallURL = link
        }
        if let models = decoded.models, !models.isEmpty {
            AppGroupService.shared.remoteModelCatalog = models
        }
    }
}
