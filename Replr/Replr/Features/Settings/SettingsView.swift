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
    @State private var pendingShots = ScreenshotCleaner.pendingCount()
    @State private var showTutorial = false
    @State private var aboutUser = AppGroupService.shared.aboutUser
    @FocusState private var aboutFocused: Bool

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
                    "A few words about you — age, gender, your vibe, what you're into. Helps Replr sound like you.\ne.g. 27, guy, dry sense of humour, into climbing and techno.",
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
            HStack(spacing: 0) {
                modelOption("claude-sonnet-4-6", label: "Claude Sonnet")
                ReplrTheme.Color.glassBorder.frame(width: 1, height: 24)
                modelOption("gpt-5.4", label: "GPT-5.4")
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private func modelOption(_ modelID: String, label: String) -> some View {
        let isSelected = selectedModel == modelID
        Button {
            selectedModel = modelID
            AppGroupService.shared.userModel = modelID   // always writes production choice
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
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
            Text("Only deletes screenshots Replr captured for replies — never your other photos. iOS asks you to confirm.")
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
            NavigationLink(destination: CreditPacksView()) {
                settingsRow {
                    Text("Subscription")
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

