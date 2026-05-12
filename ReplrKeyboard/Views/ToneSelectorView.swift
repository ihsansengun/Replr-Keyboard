import UIKit

final class ToneSelectorView: UIButton {
    var selectedTone: Tone {
        didSet { updateTitle() }
    }
    var onToneSelected: ((Tone) -> Void)?
    private var tones: [Tone] = []

    init(tone: Tone) {
        self.selectedTone = tone
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        setTitleColor(.label, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        updateTitle()
        addTarget(self, action: #selector(showPicker), for: .touchUpInside)
        reload()
    }

    func reload() {
        tones = AppGroupService.shared.readTones()
    }

    private func updateTitle() {
        setTitle("\(selectedTone.name) ▾", for: .normal)
    }

    @objc private func showPicker() {
        guard let vc = findViewController() else { return }
        let sheet = UIAlertController(title: "Select Tone", message: nil, preferredStyle: .actionSheet)
        for tone in tones {
            sheet.addAction(UIAlertAction(title: tone.name, style: .default) { [weak self] _ in
                self?.selectedTone = tone
                self?.onToneSelected?(tone)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        vc.present(sheet, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}
