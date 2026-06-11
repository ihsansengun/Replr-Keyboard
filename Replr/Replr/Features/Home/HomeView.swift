import SwiftUI
import Photos
import Combine

final class HomeViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []
    @Published var fullAccess = false
    @Published var photosOK = false
    @Published var backTapSkipped = false
    @Published var activeToneName = ""
    @Published var aboutAdded = false

    var setupComplete: Bool { fullAccess && photosOK }
    var recent: [CaptureSession] { Array(sessions.prefix(4)) }

    func refresh() {
        AppGroupService.shared.synchronize()
        sessions = AppGroupService.shared.loadCaptureSessions().reversed()
        fullAccess = AppGroupService.shared.fullAccessGranted
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosOK = status == .authorized || status == .limited
        backTapSkipped = AppGroupService.shared.backTapSkipped
        activeToneName = AppGroupService.shared.readSelectedTone().name
        aboutAdded = !AppGroupService.shared.aboutUser.isEmpty
        CreditsManager.shared.refreshBalance()
    }
}

/// Mission control: setup state, credits, recent replies, personalization.
struct HomeView: View {
    @Binding var selectedTab: TabSelection
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var credits = CreditsManager.shared
    @State private var showSetup = false
    @State private var showBackTap = false
    @State private var showTutorial = false
    @State private var showTones = false
    @Environment(\.scenePhase) private var scenePhase

    private var costPerReply: Int { AppGroupService.shared.creditsRequired }
    private var devMode: Bool { AppGroupService.shared.devMode }
    private var lowBalance: Bool {
        HomeLogic.isLowBalance(balance: credits.balance,
                               costPerReply: costPerReply, devMode: devMode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !vm.setupComplete { setupCard }
                    if vm.setupComplete && vm.backTapSkipped { backTapRow }
                    creditsCard
                    personalizeTiles
                    if vm.sessions.isEmpty { howItWorksCard } else { recentSection }
                    Spacer(minLength: 110) // clearance for floating tab pill
                }
                .padding(20)
            }
            .brandScreenBackground()
            .navigationTitle("Replr")
            .navigationBarTitleDisplayMode(.inline)
            .tint(ReplrTheme.Color.accent)
        }
        .onAppear { vm.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { vm.refresh() }
        }
        .sheet(isPresented: $showSetup) {
            OnboardingView(
                onComplete: { showSetup = false; vm.refresh() },
                onSignIn: { showSetup = false },
                startAtSetup: true
            )
        }
        .sheet(isPresented: $showBackTap) {
            BackTapSetupFullView(isPresented: $showBackTap)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            UsageTutorialView(onDone: { showTutorial = false })
        }
        .sheet(isPresented: $showTones, onDismiss: { vm.refresh() }) {
            TonesView()
        }
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finish setting up")
                .font(ReplrTheme.Font.headline)
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            setupRow("Keyboard & Full Access", on: vm.fullAccess)
            setupRow("Photos access", on: vm.photosOK)
            PrimaryButton(label: "Finish setup") { showSetup = true }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(ReplrTheme.Color.accent.opacity(0.45), lineWidth: 1.5)
        )
    }

    private func setupRow(_ title: String, on: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(on ? ReplrTheme.Color.success : ReplrTheme.Color.textTertiary)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Spacer()
        }
    }

    private var backTapRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .font(.system(size: 14))
                .foregroundStyle(ReplrTheme.Color.accent)
            Text("Back Tap: screenshot anywhere, no keyboard needed")
                .font(.system(size: 13))
                .foregroundStyle(ReplrTheme.Color.textSecondary)
            Spacer()
            Button("Set up") { showBackTap = true }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.accent)
                .buttonStyle(.plain)
            Button {
                AppGroupService.shared.backTapSkipped = false
                withAnimation(ReplrTheme.Motion.quick) { vm.backTapSkipped = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(ReplrTheme.Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Credits

    private var creditsCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(devMode ? "∞" : credits.balanceDisplay)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                    Text("credits")
                        .font(.system(size: 13))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
                Text(creditsSubline)
                    .font(.system(size: 12))
                    .foregroundStyle(lowBalance ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary)
            }
            Spacer()
            NavigationLink(destination: CreditPacksView()) {
                // The one gradient moment on Home — the system's hero-CTA treatment.
                Text(lowBalance ? "Top up" : "Get more")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(ReplrTheme.Color.brandGradient))
                    .shadow(color: ReplrTheme.Color.accentGlow, radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .brandCard()
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(lowBalance ? ReplrTheme.Color.accent.opacity(0.45) : .clear, lineWidth: 1.5)
        )
    }

    private var creditsSubline: String {
        if devMode { return "Dev mode — replies are free" }
        let n = HomeLogic.approxReplies(balance: credits.balance,
                                        costPerReply: costPerReply)
        if n == 0 { return "Not enough for a reply" }
        return "≈ \(n) repl\(n == 1 ? "y" : "ies")"
    }

    // MARK: - How it works (until first capture)

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Replr works")
                .font(ReplrTheme.Font.headline)
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            stepRow("1", "Open a chat and switch to the Replr keyboard (🌐).")
            stepRow("2", "Tap \u{201C}Start\u{201D}, then screenshot the chat.")
            stepRow("3", "Tap a reply to send it.")
            Button { showTutorial = true } label: {
                Text("Watch how →")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.accent)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func stepRow(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(ReplrTheme.Color.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ReplrTheme.Color.accent))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                Spacer()
                Button { selectedTab = .history } label: {
                    Text("See all →")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ReplrTheme.Color.accent)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            ForEach(vm.recent) { session in
                NavigationLink(destination: CaptureDetailView(session: session)) {
                    HStack(spacing: 10) {
                        InitialAvatar(name: session.contactName, size: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(session.contactName ?? recentTime(session.timestamp))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                                    .lineLimit(1)
                                if session.contactName != nil {
                                    Text(recentTime(session.timestamp))
                                        .font(.system(size: 11))
                                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                                }
                            }
                            if let summary = session.llmSummary {
                                Text(summary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                }
                .buttonStyle(.plain)
                .brandCard()
            }
        }
    }

    private func recentTime(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return date.formatted(.dateTime.hour().minute()) }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Personalize

    private var personalizeTiles: some View {
        HStack(spacing: 10) {
            Button { showTones = true } label: {
                tile(caption: "Tone", value: vm.activeToneName)
            }
            .buttonStyle(.plain)
            NavigationLink(destination: AboutYouView().onDisappear { vm.refresh() }) {
                tile(caption: "About you", value: vm.aboutAdded ? "Added ✓" : "Add")
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(caption: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(ReplrTheme.Color.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
