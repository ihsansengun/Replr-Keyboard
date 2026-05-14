import UIKit

final class ReplyCardsView: UIView, UIScrollViewDelegate {
    var onSelect: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let counterLabel = UILabel()
    private let replies: [String]
    private var hasBuiltCards = false
    private var currentPage = 0 {
        didSet { counterLabel.text = "\(currentPage + 1) / \(replies.count)" }
    }

    init(replies: [String]) {
        self.replies = replies
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear

        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = true
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        counterLabel.text = "1 / \(replies.count)"
        counterLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        counterLabel.textColor = .tertiaryLabel
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(counterLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            counterLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            counterLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasBuiltCards, scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }
        hasBuiltCards = true
        buildCards()
    }

    private func buildCards() {
        let w = scrollView.bounds.width
        let h = scrollView.bounds.height
        for (i, reply) in replies.enumerated() {
            let card = ReplyCardView(reply: reply)
            card.onTap = { [weak self] text in self?.onSelect?(text) }
            card.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
            scrollView.addSubview(card)
        }
        scrollView.contentSize = CGSize(width: w * CGFloat(replies.count), height: h)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        currentPage = max(0, min(Int(scrollView.contentOffset.x / scrollView.bounds.width + 0.5), replies.count - 1))
    }
}
