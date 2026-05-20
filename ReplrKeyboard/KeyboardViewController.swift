import UIKit
import SwiftUI
import Combine

final class KeyboardViewController: UIInputViewController {
    private var model: KeyboardModel!
    private var capturePollingTask: Task<Void, Never>?
    private var heightConstraint: NSLayoutConstraint!
    private var stateCancellable: AnyCancellable?
    private var hostingVC: UIHostingController<KeyboardRootView>!

    override func viewDidLoad() {
        super.viewDidLoad()

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 316)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        let defaultTone = AppGroupService.shared.readSelectedTone()
        model = KeyboardModel(initialTone: defaultTone)
        model.onReplySelected = { [weak self] reply in self?.insert(reply) }
        model.onToneChanged = { tone in AppGroupService.shared.saveSelectedTone(tone) }
        model.onSwitchKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        model.onUseAsContext = { [weak self] in
            guard let self else { return }
            AppGroupService.shared.savePendingContext(self.model.pendingContext)
            let draft = self.textDocumentProxy.documentContextBeforeInput ?? ""
            for _ in draft.unicodeScalars { self.textDocumentProxy.deleteBackward() }
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
        model.retryTrigger = { [weak self] in self?.triggerRetry() }
        model.readTextProxy = { [weak self] in self?.textDocumentProxy.documentContextBeforeInput }
        model.onDeleteTextProxy = { [weak self] in
            guard let self else { return }
            let draft = self.textDocumentProxy.documentContextBeforeInput ?? ""
            for _ in draft.unicodeScalars { self.textDocumentProxy.deleteBackward() }
        }

        model.onCreateNewContact = { [weak self] name in
            guard let self else { return }
            let newContact = AppGroupService.shared.createContact(displayName: name)
            AppGroupService.shared.currentContactID = newContact.id
            self.model.contactName = name
            withAnimation(.easeInOut(duration: 0.18)) {
                self.model.state = self.model.currentReplies.isEmpty
                    ? .idle
                    : .replies(self.model.currentReplies)
            }
        }

        hostingVC = UIHostingController(rootView: KeyboardRootView(model: model))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.insetsLayoutMarginsFromSafeArea = false
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

        stateCancellable = Publishers.CombineLatest(model.$state, model.$inputMode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, inputMode in
                guard let self else { return }
                switch state {
                case .replies:
                    // Measure natural content height so the card fills exactly what it needs
                    self.updateHeightFromContent()
                default:
                    let newHeight: CGFloat
                    switch state {
                    case .idle:          newHeight = 316
                    case .loading:       newHeight = 316
                    case .error:         newHeight = 316
                    case .disambiguate:  newHeight = 356
                    case .replies:       newHeight = 356  // unreachable — handled above
                    }
                    self.setHeight(newHeight)
                }
            }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.needsGlobeKey = needsInputModeSwitchKey

        // Resolve contact display name from App Group
        if let id = AppGroupService.shared.currentContactID,
           let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
            model.contactName = contact.displayName
        } else {
            model.contactName = nil
        }
        model.hasAnySessions = !AppGroupService.shared.loadCaptureSessions().isEmpty
        model.intentHint = AppGroupService.shared.readIntentHint()

        if AppGroupService.shared.isGenerating {
            model.state = .loading
        } else if AppGroupService.shared.persistReplies,
                  let cached = AppGroupService.shared.readCachedReplies() {
            model.currentReplies = cached
            model.state = .replies(cached)
        }
        startCapturePoll()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        model?.needsGlobeKey = needsInputModeSwitchKey
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
                if AppGroupService.shared.isGenerating {
                    await MainActor.run {
                        if self.model.state != .loading {
                            withAnimation(.easeInOut(duration: 0.2)) { self.model.state = .loading }
                        }
                    }
                } else if let replies = AppGroupService.shared.consumeReplies() {
                    NSLog("[Replr][Keyboard] poll: %d replies", replies.count)
                    AppGroupService.shared.savePendingContext("")  // context consumed, reset for next use
                    await MainActor.run {
                        self.model.currentReplies = replies
                        // Refresh contact chip — intent may have switched contact during this capture
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
                        withAnimation { self.model.state = .error(error) }
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
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
        AppGroupService.shared.saveIntentHint(nil)
        model.intentHint = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        model.lastInsertedReply = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.model.lastInsertedReply = nil
        }
    }

    private func undoLastInsert() {
        guard let text = model.lastInsertedReply else { return }
        for _ in text { textDocumentProxy.deleteBackward() }
        model.lastInsertedReply = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func triggerRetry() {
        capturePollingTask?.cancel()
        capturePollingTask = nil
        startCapturePoll()
    }

    private func setHeight(_ height: CGFloat) {
        guard heightConstraint.constant != height else { return }
        heightConstraint.constant = height
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    // Picks a replies height based on content: email replies are longer so get more space.
    // The card uses maxHeight:.infinity so it fills whatever height we allocate here.
    private func updateHeightFromContent() {
        // Strip (68) + optional contact row (28) + carousel padding/dots (~32)
        let chrome: CGFloat = 68 + (model.contactName != nil ? 28 : 0) + 32
        let longestReply = model.currentReplies.map(\.count).max() ?? 0
        let cardHeight: CGFloat
        if model.inputMode == .email {
            // Email bodies: scale from 200px (short) up to 340px (long)
            cardHeight = min(340, max(200, CGFloat(longestReply) * 0.8))
        } else {
            // Chat replies are short — scale from 110px up to 200px
            cardHeight = min(200, max(110, CGFloat(longestReply) * 1.2))
        }
        setHeight(chrome + cardHeight)
    }
}
