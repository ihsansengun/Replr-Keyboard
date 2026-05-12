import Foundation
import UIKit

final class AppGroupService {
    static let shared = AppGroupService()

    private let container: URL

    private init() {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupID
        ) else { fatalError("App Group not configured: \(Constants.appGroupID)") }
        container = url
    }

    // MARK: - Screenshot

    func writeScreenshot(_ image: UIImage) throws {
        guard let data = image.pngData() else { throw AppGroupError.encodingFailed }
        let url = container.appendingPathComponent(Constants.screenshotFilename)
        try data.write(to: url, options: .atomic)
    }

    func readScreenshot() throws -> UIImage {
        let url = container.appendingPathComponent(Constants.screenshotFilename)
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else { throw AppGroupError.decodingFailed }
        return image
    }

    // MARK: - Capture Ready Flag

    var isCaptureReady: Bool {
        get { UserDefaults(suiteName: Constants.appGroupID)?.bool(forKey: Constants.captureReadyKey) ?? false }
        set { UserDefaults(suiteName: Constants.appGroupID)?.set(newValue, forKey: Constants.captureReadyKey) }
    }

    // MARK: - Tones

    func writeTones(_ tones: [Tone]) throws {
        let data = try JSONEncoder().encode(tones)
        UserDefaults(suiteName: Constants.appGroupID)?.set(data, forKey: Constants.tonesKey)
    }

    func readTones() -> [Tone] {
        guard
            let data = UserDefaults(suiteName: Constants.appGroupID)?.data(forKey: Constants.tonesKey),
            let tones = try? JSONDecoder().decode([Tone].self, from: data)
        else { return Tone.presets }
        return tones
    }

    // MARK: - User ID

    func userID() -> String {
        let defaults = UserDefaults(suiteName: Constants.appGroupID)
        if let id = defaults?.string(forKey: Constants.userIDKey) { return id }
        let id = UUID().uuidString
        defaults?.set(id, forKey: Constants.userIDKey)
        return id
    }
}

enum AppGroupError: Error {
    case encodingFailed
    case decodingFailed
}
