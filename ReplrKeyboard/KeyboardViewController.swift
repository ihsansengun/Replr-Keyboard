import UIKit
import SwiftUI
import Combine

final class KeyboardViewController: UIInputViewController {
    private var model: KeyboardModel!
    private var capturePollingTask: Task<Void, Never>?
    private var heightConstraint: NSLayoutConstraint!
    private var autoSwitchTask: DispatchWorkItem?
    private var stateCancellable: AnyCancellable?
    private var collapseCancellable: AnyCancellable?
    private var hostingVC: UIHostingController<KeyboardRootView>!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Register the shared Fraunces font (copied to the App Group by the app) so the keyboard's
        // serif headlines render in Fraunces rather than the system-serif fallback.
        AppGroupService.shared.registerSerifFont()
        // NOTE: hasFullAccess is unreliable in viewDidLoad (host connection not yet established).
        // The setup flags are recorded in viewDidAppear instead.

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 270)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        let defaultTone = AppGroupService.shared.readSelectedTone()
        model = KeyboardModel(initialTone: defaultTone)
        model.onReplySelected = { [weak self] reply in self?.insert(reply) }
        model.onToneChanged = { tone in AppGroupService.shared.saveSelectedTone(tone) }
        model.onSwitchKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        model.onOpenContainingApp = { [weak self] urlString in
            guard let url = URL(string: urlString) else { return }
            // Public API; may no-op on some iOS versions — the app also shows the paywall
            // on next foreground when credits are 0, so this is a best-effort shortcut.
            self?.extensionContext?.open(url, completionHandler: nil)
        }
        model.onSelectContact = { [weak self] contact in
            guard let self else { return }
            AppGroupService.shared.currentContactID = contact.id
            self.model.contactName = contact.displayName
            withAnimation(.easeInOut(duration: 0.18)) {
                self.model.state = self.model.currentReplies.isEmpty
                    ? .idle
                    : .replies(self.model.currentReplies)
            }
        }

        model.onUndoInsert = { [weak self] in self?.undoLastInsert() }
        model.onEditReply = { [weak self] reply in
            guard let self else { return }
            self.autoSwitchTask?.cancel()
            self.autoSwitchTask = nil
            self.model.lastInsertedReply = nil
            let ctx = self.textDocumentProxy.documentContextBeforeInput ?? ""
            for _ in ctx.unicodeScalars { self.textDocumentProxy.deleteBackward() }
            self.textDocumentProxy.insertText(reply)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self.advanceToNextInputMode()
        }
        model.retryTrigger = { [weak self] in self?.triggerRetry() }
        model.onContentHeightChanged = { [weak self] height in
            guard let self else { return }
            self.setHeight(min(560, max(260, height)), duration: 0.15)
        }

        let adaptiveBg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.082, green: 0.063, blue: 0.102, alpha: 1) // #15101A
                : UIColor(red: 1.000, green: 0.973, blue: 0.961, alpha: 1) // #FFF8F5 warm white
        }
        view.backgroundColor = adaptiveBg

        hostingVC = UIHostingController(rootView: KeyboardRootView(model: model))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.insetsLayoutMarginsFromSafeArea = false
        // Mirror the input controller's style so SwiftUI always gets the right color scheme —
        // keyboard extensions sometimes inherit a stale dark trait from the host app.
        hostingVC.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
        addChild(hostingVC)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingVC.view)
        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingVC.didMove(toParent: self)

        stateCancellable = model.$state
            .combineLatest(model.$isCaptureMode)
            .combineLatest(model.$inputMode)
            .combineLatest(model.$isCollapsed)
            .combineLatest(model.$detectedScreenshotID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] combined, detectedID in
                guard let self else { return }
                let (((state, isCaptureMode), inputMode), isCollapsed) = combined
                if isCaptureMode {
                    self.setHeight(0, duration: 0.15)
                    return
                }
                if isCollapsed {
                    let defaults = UserDefaults(suiteName: Constants.appGroupID)
                    defaults?.synchronize()
                    let coachmarkSeen = defaults?.bool(forKey: Constants.coachmarkSeenKey) ?? false
                    self.setHeight(coachmarkSeen ? 90 : 140)
                    return
                }
                let height: CGFloat
                switch state {
                case .idle:         height = (detectedID != nil) ? 300 : (inputMode == .email ? 224 : 300)
                case .loading:      height = 310
                case .error:        height = 240
                case .paywall:      height = 280
                case .disambiguate: height = 300
                case .replies:
                    // The exact height comes from RepliesPanelView.onContentHeightChanged, which
                    // measures the real rendered content. We only set a sane floor here and never
                    // use sizeThatFits — it returns near-max values pre-layout and in some hosts
                    // (e.g. FaceTime via Back Tap), which opened the keyboard "huge".
                    height = max(320, min(560, self.heightConstraint.constant))
                }
                self.setHeight(height)
            }

        // On collapse: persist context to App Group (so intent can read it) then clear the input field
        // so the screenshot doesn't show the typed hint alongside the saved prompt context.
        collapseCancellable = model.$isCollapsed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isCollapsed in
                guard let self, isCollapsed else { return }
                self.model.captureBaselineScreenshotID = PhotosCapture.latestScreenshotID()
                self.model.collapseStartedAt = Date()
                self.model.showFullScreenPreviewHint = false
                let ctx = self.model.pendingContext
                AppGroupService.shared.savePendingContext(ctx)
                let fieldText = self.textDocumentProxy.documentContextBeforeInput ?? ""
                for _ in fieldText.unicodeScalars { self.textDocumentProxy.deleteBackward() }
                self.model.clearRepliesForCapture()
            }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.isCaptureMode = false   // safety reset — ensures 0px collapse never gets stuck
        model.isCollapsed = false
        // Arm the screenshot watcher from the moment the keyboard opens, so a screenshot taken
        // with the keyboard still up (no Start tap) is still caught. Baseline = newest existing
        // shot, so only a screenshot taken AFTER this point triggers a capture.
        model.detectedScreenshotID = nil
        model.captureBaselineScreenshotID = PhotosCapture.latestScreenshotID()

        // Resolve contact display name from App Group
        AppGroupService.shared.synchronize()
        if let id = AppGroupService.shared.currentContactID,
           let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
            model.contactName = contact.displayName
        } else {
            model.contactName = nil
        }
        model.hasAnySessions = !AppGroupService.shared.loadCaptureSessions().isEmpty
        model.selectedDevModel = AppGroupService.shared.selectedModel   // keep dev switcher in sync

        if AppGroupService.shared.isGenerating {
            model.state = .loading
        } else if AppGroupService.shared.persistReplies,
                  let cached = AppGroupService.shared.readCachedReplies() {
            // Keep-replies: restore the last replies on reopen. The height is (re)computed in
            // viewDidAppear — sizeThatFits is unreliable here, before the view is laid out.
            model.currentReplies = cached
            model.repliesGeneratedInMode = .chat
            model.state = .replies(cached)
        }
        if AppGroupService.shared.effectiveCreditBalance == 0 {
            model.state = .paywall
        }
        startCapturePoll()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Connection to host app is established by now — hasFullAccess is reliable here
        // (it is NOT in viewDidLoad), so this is where we record the setup flags.
        if hasFullAccess {
            AppGroupService.shared.keyboardInstalled = true
            AppGroupService.shared.fullAccessGranted = true
        }
        // Connection to host app is established by now — safe to read needsInputModeSwitchKey.
        model.needsGlobeKey = needsInputModeSwitchKey
        // documentContextBeforeInput is unreliable until the proxy fully connects;
        // a short delay ensures we read the actual pre-existing draft text.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000) // 0.08 s
            guard let self else { return }
            let draft = self.textDocumentProxy.documentContextBeforeInput ?? ""
            self.model.pendingContext = draft
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        let draft = textDocumentProxy.documentContextBeforeInput ?? ""
        model.pendingContext = draft   // display only — not saved to App Group
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            hostingVC?.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Only update after the view is visible — avoids the pre-connection warning.
        if viewIfLoaded?.window != nil {
            model?.needsGlobeKey = needsInputModeSwitchKey
        }
    }

    // Replies height is driven by RepliesPanelView's per-piece ContentHeightSumKey → onContentHeightChanged
    // (clamped to [260, 560]). It measures the natural content height independently of the frame, and the
    // panel pins its header + action row while the cards scroll, so content never clips and the keyboard
    // never exceeds the cap. No sizeThatFits here — with the cards in a flexible ScrollView it would read
    // a greedy near-max value and force the keyboard to its cap every time.

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        capturePollingTask?.cancel()
        capturePollingTask = nil
    }

    // MARK: - Poll App Group for replies written by the AppIntent

    private func startCapturePoll() {
        capturePollingTask?.cancel()
        capturePollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if AppGroupService.shared.effectiveCreditBalance == 0 {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) { self.model.state = .paywall }
                    }
                } else if AppGroupService.shared.switchKeyboardRequested {
                    AppGroupService.shared.setSwitchKeyboardRequested(false)
                    await MainActor.run { self.model.isCaptureMode = true }
                } else if AppGroupService.shared.isGenerating {
                    await MainActor.run {
                        if self.model.state != .loading {
                            withAnimation(.easeInOut(duration: 0.2)) { self.model.state = .loading }
                        }
                    }
                } else if let replies = AppGroupService.shared.consumeReplies() {
                    NSLog("[Replr][Keyboard] poll: %d replies", replies.count)
                    AppGroupService.shared.savePendingContext("")  // context consumed, reset for next use
                    let memoryContact = AppGroupService.shared.memoryUsedContactName
                    AppGroupService.shared.memoryUsedContactName = nil
                    await MainActor.run {
                        self.model.isCaptureMode = false
                        self.model.isCollapsed = false
                        self.model.memoryContactName = memoryContact
                        if !AppGroupService.shared.hasConsentedToCapture {
                            self.model.showConsentPrompt = true
                        }
                        self.model.currentReplies = replies
                        self.model.repliesGeneratedInMode = .chat
                        // Refresh contact chip — intent may have switched contact during this capture
                        AppGroupService.shared.synchronize()
                        if let id = AppGroupService.shared.currentContactID,
                           let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
                            self.model.contactName = contact.displayName
                        } else {
                            self.model.contactName = nil
                        }
                        self.model.hasAnySessions = true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.model.state = .replies(replies)
                        }
                    }
                } else if let error = AppGroupService.shared.consumeError() {
                    NSLog("[Replr][Keyboard] poll error: %@", error)
                    await MainActor.run {
                        self.model.isCaptureMode = false
                        self.model.isCollapsed = false
                        // Intent captures are screenshots → a retry must read the saved screenshot.
                        self.model.repliesGeneratedInMode = .chat
                        withAnimation { self.model.state = .error(error) }
                    }
                }

                // Photos watcher: arm on a screenshot newer than the baseline. Watches whenever the
                // keyboard is idle — after the user taps Start (collapsed) OR with the keyboard still
                // open — so Start is optional and a screenshot is caught either way.
                let (idle, collapsed, alreadyDetected, baseline, collapsedAt) = await MainActor.run {
                    (self.model.isIdleState,
                     self.model.isCollapsed,
                     self.model.detectedScreenshotID != nil,
                     self.model.captureBaselineScreenshotID,
                     self.model.collapseStartedAt)
                }
                if idle && !alreadyDetected {
                    if let latest = PhotosCapture.latestScreenshotID(), latest != baseline {
                        NSLog("[Replr][Keyboard] new screenshot detected: %@", latest)
                        await MainActor.run { self.model.detectedScreenshotID = latest }
                    } else if collapsed,
                              ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26,
                              let started = collapsedAt, Date().timeIntervalSince(started) > 5 {
                        await MainActor.run { self.model.showFullScreenPreviewHint = true }
                    }
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    // MARK: - Insert reply then hand back to previous keyboard

    private func insert(_ text: String) {
        let ctx = textDocumentProxy.documentContextBeforeInput ?? ""
        for _ in ctx.unicodeScalars { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(text)
        model.pendingContext = ""
        AppGroupService.shared.savePendingContext("")
        AppGroupService.shared.markLastSessionReplySelected(text)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        model.lastInsertedReply = text

        autoSwitchTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.model.lastInsertedReply != nil else { return }
            self.model.lastInsertedReply = nil
            self.advanceToNextInputMode()
        }
        autoSwitchTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }

    private func undoLastInsert() {
        guard let text = model.lastInsertedReply else { return }
        for _ in text { textDocumentProxy.deleteBackward() }
        model.lastInsertedReply = nil
        autoSwitchTask?.cancel()
        autoSwitchTask = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func triggerRetry() {
        capturePollingTask?.cancel()
        capturePollingTask = nil
        startCapturePoll()
    }

    private func setHeight(_ height: CGFloat, duration: TimeInterval = 0.25) {
        guard heightConstraint.constant != height else { return }
        heightConstraint.constant = height
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }
}
