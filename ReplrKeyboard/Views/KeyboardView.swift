import UIKit
import ReplayKit

enum KeyboardState {
    case idle
    case loading
    case replies([String])
    case error(String)
}

final class KeyboardView: UIView {
    var onCapture: (() -> Void)?
    var onReplySelected: ((String) -> Void)?
    var onSwitchKeyboard: (() -> Void)?
    var onToneChanged: ((Tone) -> Void)?

    private let toolbar = UIView()
    private let captureButton = UIButton(type: .system)
    private let toneSelector: ToneSelectorView
    private let switchButton = UIButton(type: .system)
    private let contentContainer = UIView()

    private(set) var selectedTone: Tone

    init(initialTone: Tone) {
        self.selectedTone = initialTone
        self.toneSelector = ToneSelectorView(tone: initialTone)
        super.init(frame: .zero)
        setup()
        transition(to: .idle)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .systemBackground

        captureButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)

        toneSelector.onToneSelected = { [weak self] tone in
            self?.selectedTone = tone
            self?.onToneChanged?(tone)
        }

        switchButton.setImage(UIImage(systemName: "globe"), for: .normal)
        switchButton.addTarget(self, action: #selector(switchTapped), for: .touchUpInside)

        [captureButton, toneSelector, switchButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            toolbar.addSubview($0)
        }

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toolbar)
        addSubview(contentContainer)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),

            captureButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 12),
            captureButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 44),
            captureButton.heightAnchor.constraint(equalToConstant: 44),

            toneSelector.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor),
            toneSelector.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            switchButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -12),
            switchButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 44),
            switchButton.heightAnchor.constraint(equalToConstant: 44),

            contentContainer.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func transition(to state: KeyboardState) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        let content: UIView
        switch state {
        case .idle:
            content = IdleView()
        case .loading:
            content = LoadingView()
        case .replies(let replies):
            content = buildRepliesView(replies)
        case .error(let message):
            content = buildErrorView(message)
        }

        content.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])
    }

    private func buildRepliesView(_ replies: [String]) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.isLayoutMarginsRelativeArrangement = true

        for reply in replies {
            let card = ReplyCardView(reply: reply)
            card.onTap = { [weak self] text in self?.onReplySelected?(text) }
            stack.addArrangedSubview(card)
        }

        let regenButton = UIButton(type: .system)
        regenButton.setTitle("Try again ↺", for: .normal)
        regenButton.titleLabel?.font = .systemFont(ofSize: 13)
        regenButton.addAction(UIAction { [weak self] _ in self?.onCapture?() }, for: .touchUpInside)
        stack.addArrangedSubview(regenButton)

        return stack
    }

    private func buildErrorView(_ message: String) -> UIView {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }

    @objc private func captureTapped() { onCapture?() }
    @objc private func switchTapped() { onSwitchKeyboard?() }
}
