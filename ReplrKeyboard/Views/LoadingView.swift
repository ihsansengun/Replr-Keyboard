import UIKit

final class LoadingView: UIView {
    private let activity = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .systemBackground
        label.text = "Generating..."
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [activity, label])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        activity.startAnimating()
    }
}
