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

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 220)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        let defaultTone = AppGroupService.shared.readSelectedTone()
        model = KeyboardModel(initialTone: defaultTone)
        model.onReplySelected = { [weak self] reply in self?.insert(reply) }
        model.onToneChanged = { tone in AppGroupService.shared.saveSelectedTone(tone) }
        model.onSwitchKeyboard = { [weak self] in self?.advanceToNextInputMode() }

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
                case .editReply: newHeight = 248
                case .loading, .replies:          newHeight = 320
                default:                          newHeight = 220
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
        let draft = textDocumentProxy.documentContextBeforeInput ?? ""
        model.pendingContext = draft
        AppGroupService.shared.savePendingContext(draft)
        if AppGroupService.shared.persistReplies,
           let cached = AppGroupService.shared.readCachedReplies() {
            model.currentReplies = cached
            model.state = .replies(cached)
        }
        startCapturePoll()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        let draft = textDocumentProxy.documentContextBeforeInput ?? ""
        model.pendingContext = draft
        AppGroupService.shared.savePendingContext(draft)
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
                if let replies = AppGroupService.shared.consumeReplies() {
                    NSLog("[Replr][Keyboard] poll: %d replies", replies.count)
                    await MainActor.run {
                        self.model.currentReplies = replies
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
        textDocumentProxy.insertText(text)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
