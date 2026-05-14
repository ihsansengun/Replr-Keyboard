import UIKit

final class ReplyCardView: UIView {
    var onTap: ((String) -> Void)?
    private let textLabel = UILabel()
    private let sendIcon = UIImageView()
    private let reply: String

    init(reply: String) {
        self.reply = reply
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous

        textLabel.text = reply
        textLabel.font = .systemFont(ofSize: 15)
        textLabel.numberOfLines = 0
        textLabel.textColor = .label
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .light)
        sendIcon.image = UIImage(systemName: "arrow.up.circle.fill", withConfiguration: cfg)
        sendIcon.tintColor = .tertiaryLabel
        sendIcon.contentMode = .scaleAspectFit
        sendIcon.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textLabel)
        addSubview(sendIcon)

        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textLabel.bottomAnchor.constraint(lessThanOrEqualTo: sendIcon.topAnchor, constant: -8),

            sendIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            sendIcon.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            sendIcon.widthAnchor.constraint(equalToConstant: 22),
            sendIcon.heightAnchor.constraint(equalToConstant: 22),
        ])

        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.08) { self.alpha = 0.6 }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.1) { self.alpha = 1 }
    }

    @objc private func tapped() { onTap?(reply) }
}
