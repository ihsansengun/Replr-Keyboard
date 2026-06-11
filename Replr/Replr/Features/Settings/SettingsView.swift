import SwiftUI
import Photos

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
                         ? "Everything Replr needs is enabled. You're good to go."
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
    let activeTab: TabSelection
    @AppStorage(Constants.colorSchemeAppearanceKey) private var colorSchemeAppearance = "system"
    @State private var persistReplies = AppGroupService.shared.persistReplies
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var autoClear = AppGroupService.shared.autoClearScreenshots
    @State private var activeToneName = AppGroupService.shared.readSelectedTone().name
    @State private var aboutUser = AppGroupService.shared.aboutUser
    @State private var selectedModel = AppGroupService.shared.userModel
    @State private var showModelPicker = false
    @State private var showTutorial = false
    @State private var showBackTapSetup = false
    @State private var fullAccess = AppGroupService.shared.fullAccessGranted
    @State private var photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showSignOutConfirm = false
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var credits = CreditsManager.shared
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    #endif

    private var photosOK: Bool { photosStatus == .authorized || photosStatus == .limited }
    private var setupMissing: Int { (fullAccess ? 0 : 1) + (photosOK ? 0 : 1) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    personalizeSection
                    keyboardSection
                    privacySection
                    accountSection
                    footerSection
                    Spacer(minLength: 110) // clearance for floating tab pill
                }
                .padding(20)
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            UsageTutorialView(onDone: { showTutorial = false })
        }
        .sheet(isPresented: $showBackTapSetup) {
            BackTapSetupFullView(isPresented: $showBackTapSetup)
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { phase in if phase == .active { refresh() } }
        .onChange(of: activeTab) { tab in if tab == .settings { refresh() } }
    }

    private func refresh() {
        AppGroupService.shared.synchronize()
        activeToneName = AppGroupService.shared.readSelectedTone().name
        aboutUser = AppGroupService.shared.aboutUser
        memoryEnabled = AppGroupService.shared.memoryEnabled
        autoClear = AppGroupService.shared.autoClearScreenshots
        selectedModel = AppGroupService.shared.userModel
        fullAccess = AppGroupService.shared.fullAccessGranted
        photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        CreditsManager.shared.refreshBalance()
    }

    // MARK: - Personalize

    private var personalizeSection: some View {
        SettingsCard(title: "Personalize") {
            NavigationLink(destination: AboutYouView().onDisappear {
                aboutUser = AppGroupService.shared.aboutUser
            }) {
                SettingsRow {
                    Text("About you").font(.system(size: 17))
                    Spacer()
                    RowValue(text: aboutUser.isEmpty ? "Add" : "Added ✓",
                             color: aboutUser.isEmpty ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            NavigationLink(destination: TonesView().onDisappear {
                activeToneName = AppGroupService.shared.readSelectedTone().name
            }) {
                SettingsRow {
                    Text("Tones").font(.system(size: 17))
                    Spacer()
                    RowValue(text: activeToneName)
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    modelOption("balanced", label: "Balanced", sublabel: "Recommended")
                    ReplrTheme.Color.glassBorder.frame(width: 1, height: 38)
                    modelOption("max", label: "Max", sublabel: "Best quality")
                }
                .padding(6)
                Text("Balanced 4 · Max 6 credits per reply.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Keyboard

    private var keyboardSection: some View {
        SettingsCard(title: "Keyboard") {
            NavigationLink(destination: SetupStatusView()) {
                SettingsRow {
                    Text("Set up Replr").font(.system(size: 17))
                    Spacer()
                    RowValue(text: setupMissing == 0 ? "All set ✓" : "\(setupMissing) step\(setupMissing == 1 ? "" : "s") left",
                             color: setupMissing == 0 ? ReplrTheme.Color.success : ReplrTheme.Color.accent)
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            Button { showBackTapSetup = true } label: {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Back Tap capture").font(.system(size: 17))
                        Text("Optional: screenshot anywhere, no keyboard needed")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                    Spacer()
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            Button { showTutorial = true } label: {
                SettingsRow {
                    Text("How to use Replr").font(.system(size: 17))
                    Spacer()
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            SettingsRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep replies in keyboard").font(.system(size: 17))
                    Text("They stay until you generate new ones")
                        .font(.system(size: 12))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
                Spacer()
                BrandToggle(isOn: $persistReplies)
                    .onChange(of: persistReplies) { AppGroupService.shared.persistReplies = $0 }
            }
        }
    }

    // MARK: - Privacy & data

    private var privacySection: some View {
        SettingsCard(title: "Privacy & Data") {
            NavigationLink(destination: MemorySettingsView().onDisappear {
                memoryEnabled = AppGroupService.shared.memoryEnabled
            }) {
                SettingsRow {
                    Text("Memory").font(.system(size: 17))
                    Spacer()
                    RowValue(text: memoryEnabled ? "On" : "Off")
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            NavigationLink(destination: ScreenshotSettingsView().onDisappear {
                autoClear = AppGroupService.shared.autoClearScreenshots
            }) {
                SettingsRow {
                    Text("Screenshots").font(.system(size: 17))
                    Spacer()
                    RowValue(text: autoClear ? "Auto-clear" : "Manual")
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            NavigationLink(destination: PrivacyView()) {
                SettingsRow {
                    Text("Privacy").font(.system(size: 17))
                    Spacer()
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        SettingsCard(title: "Account") {
            NavigationLink(destination: CreditPacksView()) {
                SettingsRow {
                    Text("Credits").font(.system(size: 17))
                    Spacer()
                    RowValue(text: credits.balanceDisplay)
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            SettingsRow {
                Text(auth.userEmail ?? "Signed in with Apple")
                    .font(.system(size: 15))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Sign out") { showSignOutConfirm = true }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ReplrTheme.Color.danger)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
            }
            if auth.isSignedIn {
                CardDivider()
                Button { showDeleteAccountConfirm = true } label: {
                    SettingsRow {
                        Text("Delete account")
                            .font(.system(size: 17))
                            .foregroundStyle(ReplrTheme.Color.danger)
                        Spacer()
                        if isDeletingAccount { ProgressView() }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
            }
        }
        .confirmationDialog("Sign out of Replr?",
                            isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete your account?",
                            isPresented: $showDeleteAccountConfirm,
                            titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { performDeleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and any remaining credits. It can't be undone.")
        }
        .alert("Couldn't delete account",
               isPresented: Binding(
                   get: { deleteAccountError != nil },
                   set: { if !$0 { deleteAccountError = nil } }
               )) {
            Button("OK", role: .cancel) { deleteAccountError = nil }
        } message: {
            Text(deleteAccountError ?? "")
        }
    }

    // MARK: - Footer (cold storage)

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsCard(title: "Appearance") {
                    HStack(spacing: 0) {
                        appearanceOption("system", icon: "iphone",  label: "System")
                        ReplrTheme.Color.glassBorder.frame(width: 1, height: 58)
                        appearanceOption("light",  icon: "sun.max", label: "Light")
                        ReplrTheme.Color.glassBorder.frame(width: 1, height: 58)
                        appearanceOption("dark",   icon: "moon",    label: "Dark")
                    }
                    .padding(6)
                }
                Text("Overrides the system setting for Replr only.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 4)
            }

            SettingsCard(title: "About") {
                NavigationLink(destination: ModelPickerView(), isActive: $showModelPicker) {
                    EmptyView()
                }
                SettingsRow {
                    Text("Version").font(.system(size: 17))
                    Spacer()
                    RowValue(text: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
                .onLongPressGesture(minimumDuration: 1.5) {
                    showModelPicker = true
                }
                #if DEBUG
                CardDivider()
                Button {
                    AppGroupService.shared.creditBalance = max(AppGroupService.shared.creditBalance, 40)
                    CreditsManager.shared.refreshBalance()
                    onboardingComplete = false
                } label: {
                    SettingsRow {
                        Text("Replay onboarding (+credits)").font(.system(size: 17))
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
    }

    private func performDeleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await AuthService.shared.deleteAccount()
            } catch {
                deleteAccountError = error.localizedDescription
            }
            isDeletingAccount = false
        }
    }

    private func appearanceOption(_ value: String, icon: String, label: String) -> some View {
        let isSelected = colorSchemeAppearance == value
        return Button {
            colorSchemeAppearance = value                        // standard UserDefaults → drives ReplrApp reactivity
            AppGroupService.shared.colorSchemeAppearance = value // App Group → keyboard reads this
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textPrimary)
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isSelected ? ReplrTheme.Color.accentSubtle : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .strokeBorder(
                        isSelected ? ReplrTheme.Color.accent.opacity(0.55) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(ReplrTheme.Motion.quick, value: isSelected)
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
}
