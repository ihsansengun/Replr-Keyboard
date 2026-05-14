import UIKit

final class ToneSelectorView: UIScrollView {
    var onToneSelected: ((Tone) -> Void)?
    private(set) var selectedTone: Tone
    private let stack = UIStackView()
    private var tones: [Tone] = []

    init(tone: Tone) {
        self.selectedTone = tone
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        backgroundColor = .clear

        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor),
        ])

        reload()
    }

    func reload() {
        tones = AppGroupService.shared.readTones()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tone in tones { stack.addArrangedSubview(makePill(for: tone)) }
        updateSelection()
    }

    func update(tone: Tone) {
        selectedTone = tone
        updateSelection()
    }

    private func makePill(for tone: Tone) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle(tone.name, for: .normal)
        btn.layer.cornerRadius = 14
        btn.layer.cornerCurve = .continuous
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 13, bottom: 6, right: 13)
        btn.tag = tones.firstIndex(where: { $0.id == tone.id }) ?? 0
        btn.addTarget(self, action: #selector(pillTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func pillTapped(_ sender: UIButton) {
        guard sender.tag < tones.count else { return }
        selectedTone = tones[sender.tag]
        UIView.animate(withDuration: 0.15) { self.updateSelection() }
        onToneSelected?(selectedTone)
    }

    private func updateSelection() {
        for (i, view) in stack.arrangedSubviews.enumerated() {
            guard let btn = view as? UIButton else { continue }
            let on = i < tones.count && tones[i].id == selectedTone.id
            btn.backgroundColor = on ? .label : .clear
            btn.setTitleColor(on ? .systemBackground : .secondaryLabel, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: on ? .semibold : .regular)
        }
    }
}
