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

        if hasFullAccess {
            AppGroupService.shared.keyboardInstalled = true
            AppGroupService.shared.fullAccessGranted = true
        }

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 270)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        let defaultTone = AppGroupService.shared.readSelectedTone()
        model = KeyboardModel(initialTone: defaultTone)
        model.onReplySelected = { [weak self] reply in self?.insert(reply) }
        model.onToneChanged = { tone in AppGroupService.shared.saveSelectedTone(tone) }
        model.onSwitchKeyboard = { [weak self] in self?.advanceToNextInputMode() }
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
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
                : UIColor(red: 0.961, green: 0.945, blue: 0.922, alpha: 1) // #F5F1EB warm cream
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] combined, isCollapsed in
                guard let self else { return }
                let ((state, isCaptureMode), inputMode) = combined
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
                case .idle:         height = inputMode == .email ? 224 : 310
                case .loading:      height = 250
                case .error:        height = 240
                case .paywall:      height = 280
                case .disambiguate: height = 300
                case .replies:
                    // Ask UIKit directly for the natural content size — no estimate needed.
                    // sizeThatFits returns the exact height the SwiftUI content wants to be.
                    let w = self.view.bounds.width > 0 ? self.view.bounds.width : UIScreen.main.bounds.width
                    let fit = self.hostingVC.sizeThatFits(in: CGSize(width: w, height: 10_000))
                    height = min(560, max(260, fit.height))
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

        // Resolve contact display name from App Group
        AppGroupService.shared.synchronize()
        if let id = AppGroupService.shared.currentContactID,
           let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
            model.contactName = contact.displayName
        } else {
            model.contactName = nil
        }
        model.hasAnySessions = !AppGroupService.shared.loadCaptureSessions().isEmpty

        if AppGroupService.shared.isGenerating {
            model.state = .loading
        } else if AppGroupService.shared.persistReplies,
                  let cached = AppGroupService.shared.readCachedReplies() {
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
                        withAnimation { self.model.state = .error(error) }
                    }
                }

                // Phase 1 — Photos watcher: arm on a screenshot newer than the collapse baseline
                let (collapsed, alreadyDetected, baseline, collapsedAt) = await MainActor.run {
                    (self.model.isCollapsed,
                     self.model.detectedScreenshotID != nil,
                     self.model.captureBaselineScreenshotID,
                     self.model.collapseStartedAt)
                }
                if collapsed && !alreadyDetected {
                    if let latest = PhotosCapture.latestScreenshotID(), latest != baseline {
                        NSLog("[Replr][Keyboard] new screenshot detected: %@", latest)
                        await MainActor.run { self.model.detectedScreenshotID = latest }
                    } else if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26,
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
