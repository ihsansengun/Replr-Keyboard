import SwiftUI
import PhotosUI
import AppIntents

// MARK: - Brand colors

enum Replr {
    static let accent      = Color(red: 0.831, green: 0.627, blue: 0.090) // #D4A017
    static let accentFg    = Color(red: 0.071, green: 0.055, blue: 0.000) // #120E00
    static let background  = Color(red: 0.090, green: 0.071, blue: 0.035) // #171209
    static let deep        = Color(red: 0.118, green: 0.098, blue: 0.071) // #1E1912
    static let surface     = Color(red: 0.141, green: 0.118, blue: 0.075) // #241E13
    static let borderHair  = Color(red: 0.180, green: 0.145, blue: 0.094) // #2E2518
    static let textPrimary = Color(red: 0.929, green: 0.898, blue: 0.816) // #EDE5D0
    static let textDim     = Color(red: 0.420, green: 0.376, blue: 0.314) // #6B6050

    static let uiAccent      = UIColor(red: 0.831, green: 0.627, blue: 0.090, alpha: 1)
    static let uiDeep        = UIColor(red: 0.118, green: 0.098, blue: 0.071, alpha: 1)
    static let uiBackground  = UIColor(red: 0.090, green: 0.071, blue: 0.035, alpha: 1)
    static let uiTextPrimary = UIColor(red: 0.929, green: 0.898, blue: 0.816, alpha: 1)
    static let uiTextDim     = UIColor(red: 0.420, green: 0.376, blue: 0.314, alpha: 1)
    static let uiBorderHair  = UIColor(red: 0.180, green: 0.145, blue: 0.094, alpha: 1)
}

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
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = Replr.uiDeep
        nav.titleTextAttributes = [.foregroundColor: Replr.uiTextPrimary]
        nav.largeTitleTextAttributes = [.foregroundColor: Replr.uiTextPrimary]
        nav.shadowColor = Replr.uiBorderHair
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = Replr.uiAccent

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = Replr.uiDeep
        tab.stackedLayoutAppearance.selected.iconColor = Replr.uiAccent
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: Replr.uiAccent]
        tab.stackedLayoutAppearance.normal.iconColor = Replr.uiTextDim
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: Replr.uiTextDim]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        UITableView.appearance().backgroundColor = Replr.uiBackground
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
            TonesView()
                .tabItem { Label("Tones", systemImage: "slider.horizontal.3") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Replr.accent)
        .preferredColorScheme(.dark)
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
                            .foregroundColor(Replr.accentFg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Replr.accent)
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
