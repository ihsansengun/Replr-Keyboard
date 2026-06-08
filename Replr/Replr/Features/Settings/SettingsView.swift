import SwiftUI
import Photos

/// Deletes ONLY the screenshots Replr recorded (by localIdentifier). Never touches other photos.
enum ScreenshotCleaner {
    static func pendingCount() -> Int {
        AppGroupService.shared.capturedScreenshotIDs().count
    }

    /// Batch-deletes recorded screenshots. iOS shows one confirmation. Clears the list on success.
    static func clean(completion: ((Bool) -> Void)? = nil) {
        let ids = AppGroupService.shared.capturedScreenshotIDs()
        guard !ids.isEmpty else { completion?(true); return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assets.count > 0 else {
            AppGroupService.shared.clearCapturedScreenshotIDs()   // all already gone
            completion?(true); return
        }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        } completionHandler: { success, _ in
            DispatchQueue.main.async {
                if success { AppGroupService.shared.clearCapturedScreenshotIDs() }
                completion?(success)
            }
        }
    }
}

// MARK: - Setup status (Settings → "Set up Replr")

struct SetupStatusView: View {
    @State private var fullAccess = AppGroupService.shared.fullAccessGranted
    @State private var photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showSetup = false
    @Environment(\.scenePhase) private var scenePhase

    private var photosOK: Bool { photosStatus == .authorized || photosStatus == .limited }
    private var allSet: Bool { fullAccess && photosOK }
    private var isiOS26: Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(allSet ? "You're all set." : "Finish setting up.")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                    Text(allSet
                         ? "Everything Replr needs is enabled — you're good to go."
                         : "A couple of things still need turning on.")
                        .font(.system(size: 15))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
                .padding(.top, 8)

                VStack(spacing: 0) {
                    statusRow(title: "Keyboard & Full Access", on: fullAccess)
                    Divider().overlay(ReplrTheme.Color.glassBorder).padding(.leading, 48)
                    statusRow(title: "Photos access", on: photosOK)
                }
                .background(ReplrTheme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                        .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
                )

                if isiOS26 {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(ReplrTheme.Color.textTertiary)
                        Text("Optional: turn off Full-Screen Previews (Settings → Screen Capture) so screenshots are caught hands-free.")
                            .font(.system(size: 13))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !allSet {
                    PrimaryButton(label: "Finish setup →") { showSetup = true }
                        .padding(.top, 4)
                }

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { phase in if phase == .active { refresh() } }
        .sheet(isPresented: $showSetup) {
            OnboardingView(
                onComplete: { showSetup = false; refresh() },
                onSignIn: { showSetup = false },
                startAtSetup: true
            )
        }
    }

    private func refresh() {
        AppGroupService.shared.synchronize()
        fullAccess = AppGroupService.shared.fullAccessGranted
        photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func statusRow(title: String, on: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(on ? ReplrTheme.Color.success : ReplrTheme.Color.textTertiary)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Spacer()
            Text(on ? "On" : "Off")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? ReplrTheme.Color.success : ReplrTheme.Color.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }
}

struct SettingsView: View {
    @State private var persistReplies = AppGroupService.shared.persistReplies
    @State private var memoryWindowDays = AppGroupService.shared.memoryWindowDays
    @State private var memoryDepth = AppGroupService.shared.memoryDepth
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var activeToneName = AppGroupService.shared.readSelectedTone().name
    @State private var selectedModel = AppGroupService.shared.userModel
    @State private var showModelPicker = false
    @State private var autoClear = AppGroupService.shared.autoClearScreenshots
    @State private var deleteAfterEach = AppGroupService.shared.deleteScreenshotAfterEach
    @State private var pendingShots = ScreenshotCleaner.pendingCount()
    @State private var showTutorial = false
    @State private var showBackTapSetup = false
    @State private var preferredCapture = AppGroupService.shared.preferredCapture
    @State private var aboutUser = AppGroupService.shared.aboutUser
    @FocusState private var aboutFocused: Bool
    #if DEBUG
    // Dev-only: re-trigger the onboarding flow for previewing (it's first-launch-gated).
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    identityCard
                    aboutYouSection
                    keyboardSection
                    aiModelSection
                    memorySection
                    screenshotSection
                    accountSection
                    aboutSection
                    Spacer(minLength: 110) // clearance for floating tab pill
                }
                .padding(20)
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            UsageTutorialView(onDone: { showTutorial = false })
        }
        .sheet(isPresented: $showBackTapSetup) {
            BackTapSetupFullView(isPresented: $showBackTapSetup)
        }
    }

    // MARK: - App identity

    private var identityCard: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ReplrTheme.Color.accent)
                .frame(width: 60, height: 60)
                .overlay(
                    ReplrBirdShape()
                        .fill(Color.white, style: FillStyle(eoFill: true))
                        .frame(width: 36, height: 24)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("Replr")
                    .font(.system(size: 19, weight: .bold))
                Text("Know what to say.")
                    .font(.system(size: 14))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .brandCard()
    }

    // MARK: - About You

    private var aboutYouSection: some View {
        settingsSection("About You") {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    "Age, gender, your vibe, what you're into…",
                    text: $aboutUser,
                    axis: .vertical
                )
                .font(.system(size: 15))
                .lineLimit(3...6)
                .foregroundStyle(ReplrTheme.Color.textPrimary)
                .onChange(of: aboutUser) { newValue in
                    let capped = newValue.count > 300 ? String(newValue.prefix(300)) : newValue
                    if newValue.count > 300 { aboutUser = capped }
                    AppGroupService.shared.aboutUser = capped
                }
                .focused($aboutFocused)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { aboutFocused = false }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.accent)
                    }
                }
                Text("e.g. 27, guy, dry sense of humour, into climbing and techno")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textTertiary)
                    .padding(.top, 2)

                Text("Stays on your device — sent only to draft your replies.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Keyboard

    private var keyboardSection: some View {
        settingsSection("Keyboard") {
            NavigationLink(destination: SetupStatusView()) {
                settingsRow {
                    Text("Set up Replr")
                        .font(.system(size: 17))
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 14))
                        .foregroundStyle(ReplrTheme.Color.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)

            cardDivider

            Button { showBackTapSetup = true } label: {
                settingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Back Tap capture")
                            .font(.system(size: 17))
                        Text("Optional — screenshot anywhere, no keyboard needed")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "hand.tap")
                        .font(.system(size: 14))
                        .foregroundStyle(ReplrTheme.Color.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)

            cardDivider

            // Preferred capture — tailors in-app guidance (both methods always work)
            VStack(alignment: .leading, spacing: 10) {
                Text("Preferred capture")
                    .font(.system(size: 17))
                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $preferredCapture) {
                    Text("Keyboard").tag("keyboard")
                    Text("Back Tap").tag("backtap")
                }
                .pickerStyle(.segmented)
                Text(preferredCapture == "backtap"
                     ? "Tips point to Back Tap — works anywhere, even on profiles."
                     : "Tips point to the keyboard: tap Start, then screenshot.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onChange(of: preferredCapture) { AppGroupService.shared.preferredCapture = $0 }

            cardDivider

            Button { showTutorial = true } label: {
                settingsRow {
                    Text("How to use Replr")
                        .font(.system(size: 17))
                    Spacer()
                    Image(systemName: "play.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(ReplrTheme.Color.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)

            cardDivider

            NavigationLink(destination: TonesView().onDisappear {
                activeToneName = AppGroupService.shared.readSelectedTone().name
            }) {
                settingsRow {
                    Text("Tones")
                        .font(.system(size: 17))
                    Spacer()
                    Text(activeToneName)
                        .font(.system(size: 15))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)

            cardDivider

            settingsRow {
                Text("Keep replies between sessions")
                    .font(.system(size: 17))
                Spacer()
                BrandToggle(isOn: $persistReplies)
                    .onChange(of: persistReplies) { AppGroupService.shared.persistReplies = $0 }
            }
        }
    }

    // MARK: - AI Model

    private var aiModelSection: some View {
        settingsSection("AI Model") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    modelOption("gemini-3.5-flash", label: "Gemini Flash", sublabel: "Recommended")
                    ReplrTheme.Color.glassBorder.frame(width: 1, height: 38)
                    modelOption("gemini-3.1-pro-preview", label: "Gemini Pro", sublabel: "Best quality")
                }
                .padding(6)
                Text("Flash is quick and natural — great for most replies. Pro thinks a little longer for extra-sharp ones. Switch anytime.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private func modelOption(_ modelID: String, label: String, sublabel: String) -> some View {
        let isSelected = selectedModel == modelID
        Button {
            selectedModel = modelID
            AppGroupService.shared.userModel = modelID   // always writes production choice
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textPrimary)
                Text(sublabel)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? ReplrTheme.Color.accent.opacity(0.8) : ReplrTheme.Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isSelected ? ReplrTheme.Color.accentSubtle : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .strokeBorder(isSelected ? ReplrTheme.Color.accent.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(ReplrTheme.Motion.quick, value: isSelected)
    }

    // MARK: - Memory

    private var memorySection: some View {
        settingsSection("Memory") {
            settingsRow {
                Text("Enable Memory")
                    .font(.system(size: 17))
                Spacer()
                BrandToggle(isOn: $memoryEnabled)
                    .onChange(of: memoryEnabled) { AppGroupService.shared.memoryEnabled = $0 }
            }

            if memoryEnabled {
                cardDivider

                settingsRow {
                    Text("Time window")
                        .font(.system(size: 17))
                    Spacer()
                    menuPicker(
                        label: memoryWindowDays == 0 ? "All time" : "\(memoryWindowDays) days"
                    ) {
                        Button("7 days") { memoryWindowDays = 7; AppGroupService.shared.memoryWindowDays = 7 }
                        Button("30 days") { memoryWindowDays = 30; AppGroupService.shared.memoryWindowDays = 30 }
                        Button("90 days") { memoryWindowDays = 90; AppGroupService.shared.memoryWindowDays = 90 }
                        Button("All time") { memoryWindowDays = 0; AppGroupService.shared.memoryWindowDays = 0 }
                    }
                }

                cardDivider

                settingsRow {
                    Text("Conversations per contact")
                        .font(.system(size: 17))
                    Spacer()
                    menuPicker(label: "\(memoryDepth)") {
                        Button("5") { memoryDepth = 5; AppGroupService.shared.memoryDepth = 5 }
                        Button("10") { memoryDepth = 10; AppGroupService.shared.memoryDepth = 10 }
                        Button("20") { memoryDepth = 20; AppGroupService.shared.memoryDepth = 20 }
                    }
                }
            }
        }
    }

    // MARK: - Screenshots

    private var screenshotSection: some View {
        settingsSection("Screenshots") {
            settingsRow {
                Text("Auto-clear captured screenshots")
                    .font(.system(size: 17))
                Spacer()
                BrandToggle(isOn: $autoClear)
                    .onChange(of: autoClear) { AppGroupService.shared.autoClearScreenshots = $0 }
            }
            if autoClear {
                cardDivider
                settingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete after each reply")
                            .font(.system(size: 17))
                        Text(deleteAfterEach ? "Each one, as soon as you reopen Replr" : "In batches, once a few pile up")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                    Spacer()
                    BrandToggle(isOn: $deleteAfterEach)
                        .onChange(of: deleteAfterEach) { AppGroupService.shared.deleteScreenshotAfterEach = $0 }
                }
            }
            if pendingShots > 0 {
                cardDivider
                Button {
                    ScreenshotCleaner.clean { _ in pendingShots = ScreenshotCleaner.pendingCount() }
                } label: {
                    settingsRow {
                        Text("Clear \(pendingShots) captured screenshot\(pendingShots == 1 ? "" : "s")")
                            .font(.system(size: 17))
                            .foregroundStyle(ReplrTheme.Color.accent)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            cardDivider
            Text("Only deletes screenshots Replr captured for replies — never your other photos. Cleanup runs the next time you open Replr (iOS can't let the keyboard delete photos on its own), and iOS asks you to confirm.")
                .font(.system(size: 12))
                .foregroundStyle(ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
                cardDivider
                VStack(alignment: .leading, spacing: 6) {
                    Text("Faster capture on iOS 26")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                    Text("Screenshots open a full editor instead of saving on their own. For one-tap capture, open the Settings app → Screen Capture and turn off Full-Screen Previews. Optional — capture still works; you'll just tap Save first.")
                        .font(.system(size: 12))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        settingsSection("Account") {
            // Signed-in identity
            if let email = AuthService.shared.userEmail {
                settingsRow {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(ReplrTheme.Color.accent)
                        .frame(width: 28)
                    Text(email)
                        .font(.system(size: 15))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                cardDivider
            }

            // Sign out
            Button {
                AuthService.shared.signOut()
            } label: {
                settingsRow {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(ReplrTheme.Color.danger)
                        .frame(width: 28)
                    Text("Sign out")
                        .font(.system(size: 17))
                        .foregroundColor(ReplrTheme.Color.danger)
                }
            }
            .buttonStyle(.plain)
            cardDivider

            // Existing credits row
            NavigationLink(destination: CreditPacksView()) {
                settingsRow {
                    Text("Credits")
                        .font(.system(size: 17))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        settingsSection("About") {
            NavigationLink(destination: ModelPickerView(), isActive: $showModelPicker) {
                EmptyView()
            }

            NavigationLink(destination: PrivacyView()) {
                settingsRow {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 15))
                        .foregroundStyle(ReplrTheme.Color.accent)
                        .frame(width: 22)
                    Text("Privacy")
                        .font(.system(size: 17))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)

            cardDivider

            settingsRow {
                Text("Version")
                    .font(.system(size: 17))
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.system(size: 15))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            .onLongPressGesture(minimumDuration: 1.5) {
                showModelPicker = true
            }

            #if DEBUG
            cardDivider
            Button {
                // Dev: top up credits so the live demo + first use work without reinstalling.
                AppGroupService.shared.creditBalance = max(AppGroupService.shared.creditBalance, 40)
                CreditsManager.shared.refreshBalance()
                onboardingComplete = false
            } label: {
                settingsRow {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15))
                        .foregroundStyle(ReplrTheme.Color.accent)
                        .frame(width: 22)
                    Text("Replay onboarding (+credits)")
                        .font(.system(size: 17))
                    Spacer()
                    Text("DEBUG")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    // MARK: - Reusable helpers

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .brandCard()
        }
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private var cardDivider: some View {
        ReplrTheme.Color.glassBorder
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func menuPicker<Content: View>(label: String, @ViewBuilder items: () -> Content) -> some View {
        Menu { items() } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(ReplrTheme.Color.accent)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ReplrTheme.Color.accent)
            }
        }
        .buttonStyle(.plain)
    }
}

