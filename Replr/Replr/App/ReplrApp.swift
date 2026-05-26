import SwiftUI
import PhotosUI
import AppIntents


@main
struct ReplrApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @State private var showCapture = false
    @State private var showSetup = false

    init() {
        applyBrandAppearance()
        NSLog("[Replr][Shortcuts] App init — calling updateAppShortcutParameters")
        ReplrShortcuts.updateAppShortcutParameters()
        NSLog("[Replr][Shortcuts] updateAppShortcutParameters done — shortcut count: %d", ReplrShortcuts.appShortcuts.count)
    }

    private func applyBrandAppearance() {
        let navBg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
                : UIColor(red: 0.961, green: 0.945, blue: 0.922, alpha: 1) // #F5F1EB warm cream
        }
        let accentColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.710, blue: 0.643, alpha: 1) // #0DB5A4
                : UIColor(red: 0.000, green: 0.537, blue: 0.482, alpha: 1) // #00897B
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
        }
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
