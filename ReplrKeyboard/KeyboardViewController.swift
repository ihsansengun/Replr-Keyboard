import UIKit
import ReplayKit

final class KeyboardViewController: UIInputViewController {
    private var keyboardView: KeyboardView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let tones = AppGroupService.shared.readTones()
        let defaultTone = tones.first ?? Tone.presets[0]
        keyboardView = KeyboardView(initialTone: defaultTone)
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        keyboardView.onCapture = { [weak self] in self?.startCapture() }
        keyboardView.onReplySelected = { [weak self] reply in self?.insert(reply) }
        keyboardView.onSwitchKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        keyboardView.onScrollCapture = { [weak self] in self?.startScrollCapture() }
    }

    private func startCapture() {
        CaptureService.shared.resetCaptureFlag()
        keyboardView.transition(to: .loading)
        triggerBroadcast()

        Task {
            do {
                let screenshot = try await CaptureService.shared.waitForCapture()
                let storedTxID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: "transaction_id")
                let replies = try await ReplyService.shared.generateReplies(
                    screenshot: screenshot,
                    tone: keyboardView.selectedTone,
                    summary: nil,
                    model: UserDefaults.standard.string(forKey: "preferredModel") ?? "claude",
                    transactionId: storedTxID
                )
                await MainActor.run { keyboardView.transition(to: .replies(replies)) }
            } catch {
                await MainActor.run {
                    keyboardView.transition(to: .error(error.localizedDescription))
                }
            }
        }
    }

    private func startScrollCapture() {
        ScrollCaptureService.shared.startScrollMode()
        keyboardView.transition(to: .loading)
        triggerBroadcast()

        Task {
            do {
                let screenshots = try await ScrollCaptureService.shared.waitForScrollCapture()
                ScrollCaptureService.shared.stopScrollMode()
                let storedTxID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)
                let replies = try await ReplyService.shared.generateRepliesFromScroll(
                    screenshots: screenshots,
                    tone: keyboardView.selectedTone,
                    summary: nil,
                    model: UserDefaults.standard.string(forKey: "preferredModel") ?? "claude",
                    transactionId: storedTxID
                )
                await MainActor.run { keyboardView.transition(to: .replies(replies)) }
            } catch {
                ScrollCaptureService.shared.stopScrollMode()
                await MainActor.run {
                    keyboardView.transition(to: .error(error.localizedDescription))
                }
            }
        }
    }

    private func triggerBroadcast() {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        picker.preferredExtension = Constants.broadcastExtensionID
        picker.showsMicrophoneButton = false
        view.addSubview(picker)
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .allEvents)
                break
            }
        }
        picker.removeFromSuperview()
    }

    private func insert(_ text: String) {
        textDocumentProxy.insertText(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.advanceToNextInputMode()
        }
    }
}
