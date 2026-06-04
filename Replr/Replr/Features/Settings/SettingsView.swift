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
    @State private var showSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    identityCard
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
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showSetup) {
            // Re-run the (status-aware) onboarding — skips Welcome, lands on whatever's still
            // missing, and is swipe-dismissable since this is a revisit, not first-run.
            OnboardingView(
                onComplete: { showSetup = false },
                onSignIn: { showSetup = false },
                startAtSetup: true
            )
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

    // MARK: - Keyboard

    private var keyboardSection: some View {
        settingsSection("Keyboard") {
            Button { showSetup = true } label: {
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

