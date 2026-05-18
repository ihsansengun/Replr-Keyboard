import UIKit
import SwiftUI
import Combine

final class KeyboardViewController: UIInputViewController {
    private var model: KeyboardModel!
    private var capturePollingTask: Task<Void, Never>?
    private var heightConstraint: NSLayoutConstraint!
    private var stateCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 308)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        let defaultTone = AppGroupService.shared.readSelectedTone()
        model = KeyboardModel(initialTone: defaultTone)
        model.onReplySelected = { [weak self] reply in self?.insert(reply) }
        model.onToneChanged = { tone in AppGroupService.shared.saveSelectedTone(tone) }
        model.onSwitchKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        model.onTypeChar   = { [weak self] c in self?.textDocumentProxy.insertText(c) }
        model.onDeleteChar = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        model.onSpaceChar  = { [weak self] in self?.textDocumentProxy.insertText(" ") }
        model.onReturnChar = { [weak self] in self?.textDocumentProxy.insertText("\n") }
        model.onUseAsContext = { [weak self] in
            guard let self else { return }
            AppGroupService.shared.savePendingContext(self.model.pendingContext)
            let draft = self.textDocumentProxy.documentContextBeforeInput ?? ""
            for _ in draft.unicodeScalars { self.textDocumentProxy.deleteBackward() }
        }

        model.onConfirmContact = { [weak self] newName in
            guard let self else { return }
            if let id = AppGroupService.shared.currentContactID {
                var contacts = AppGroupService.shared.loadContacts()
                if let i = contacts.firstIndex(where: { $0.id == id }) {
                    contacts[i].displayName = newName
                    AppGroupService.shared.saveContacts(contacts)
                }
            }
            self.model.contactName = newName
            withAnimation(.easeInOut(duration: 0.18)) {
                self.model.state = self.model.currentReplies.isEmpty
                    ? .idle
                    : .replies(self.model.currentReplies)
            }
        }

        model.onDifferentPerson = { [weak self] currentName in
            guard let self else { return }
            let others = AppGroupService.shared.findContacts(named: currentName)
                .filter { $0.id != AppGroupService.shared.currentContactID }
            if others.isEmpty {
                let newContact = AppGroupService.shared.createContact(displayName: currentName)
                AppGroupService.shared.currentContactID = newContact.id
                self.model.contactName = currentName
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.model.state = self.model.currentReplies.isEmpty
                        ? .idle
                        : .replies(self.model.currentReplies)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.model.state = .disambiguate(name: currentName, candidates: others)
                }
            }
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

        let hostingVC = UIHostingController(rootView: KeyboardRootView(model: model))
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

        stateCancellable = model.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let newHeight: CGFloat
                switch state {
                case .idle:          newHeight = 308
                case .collapsed:     newHeight = 44
                case .editReply:     newHeight = 308
                case .editContact:   newHeight = 308
                case .editIntent:    newHeight = 308
                case .loading:       newHeight = 308
                case .error:         newHeight = 308
                case .replies:       newHeight = 348
                case .disambiguate:  newHeight = 348
                }
                if self.heightConstraint.constant != newHeight {
                    self.heightConstraint.constant = newHeight
                    UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
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
}
