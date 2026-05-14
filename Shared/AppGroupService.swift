import Foundation
import UIKit

final class AppGroupService {
    static let shared = AppGroupService()

    private let defaults: UserDefaults
    private let container: URL

    private init() {
        guard let ud = UserDefaults(suiteName: Constants.appGroupID) else {
            fatalError("App Group not configured: \(Constants.appGroupID)")
        }
        defaults = ud

        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupID
        ) else { fatalError("App Group container not found") }
        container = url
    }

    // MARK: - Pending replies (UserDefaults — fast, no stale files)

    func saveReplies(_ replies: [String]) {
        NSLog("[Replr][AppGroup] saveReplies count=%d", replies.count)
        guard let data = try? JSONEncoder().encode(replies) else { return }
        defaults.set(data, forKey: Constants.pendingRepliesKey)
        defaults.set(true, forKey: Constants.hasNewRepliesKey)
        defaults.synchronize()
        NSLog("[Replr][AppGroup] saveReplies: wrote to UserDefaults + synchronize()")
    }

    /// Returns replies and clears the flag. Returns nil if nothing new.
    func consumeReplies() -> [String]? {
        defaults.synchronize()
        guard defaults.bool(forKey: Constants.hasNewRepliesKey) else { return nil }
        defaults.set(false, forKey: Constants.hasNewRepliesKey)
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.pendingRepliesKey),
              let replies = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        NSLog("[Replr][AppGroup] consumeReplies: got %d replies", replies.count)
        return replies
    }

    // MARK: - Error relay

    func saveError(_ message: String) {
        NSLog("[Replr][AppGroup] saveError: %@", message)
        defaults.set(message, forKey: Constants.pendingErrorKey)
        defaults.synchronize()
    }

    func consumeError() -> String? {
        defaults.synchronize()
        guard let msg = defaults.string(forKey: Constants.pendingErrorKey), !msg.isEmpty else { return nil }
        defaults.removeObject(forKey: Constants.pendingErrorKey)
        defaults.synchronize()
        return msg
    }

    // MARK: - Selected tone (keyboard writes, intent reads)

    func saveSelectedTone(_ tone: Tone) {
        guard let data = try? JSONEncoder().encode(tone) else { return }
        defaults.set(data, forKey: Constants.selectedToneKey)
        defaults.synchronize()
    }

    func readSelectedTone() -> Tone {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.selectedToneKey),
              let tone = try? JSONDecoder().decode(Tone.self, from: data) else {
            return readTones().first ?? Tone.presets[0]
        }
        return tone
    }

    // MARK: - Tones list

    func writeTones(_ tones: [Tone]) throws {
        let data = try JSONEncoder().encode(tones)
        defaults.set(data, forKey: Constants.tonesKey)
        defaults.synchronize()
    }

    func readTones() -> [Tone] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.tonesKey),
              let tones = try? JSONDecoder().decode([Tone].self, from: data) else { return Tone.presets }
        return tones
    }

    // MARK: - User ID

    func userID() -> String {
        if let id = defaults.string(forKey: Constants.userIDKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Constants.userIDKey)
        defaults.synchronize()
        return id
    }

    // MARK: - Reply context (companion app sets, keyboard shows, intent reads)

    func savePendingContext(_ text: String) {
        if text.isEmpty {
            defaults.removeObject(forKey: Constants.pendingContextKey)
        } else {
            defaults.set(text, forKey: Constants.pendingContextKey)
        }
        defaults.synchronize()
    }

    func readPendingContext() -> String? {
        defaults.synchronize()
        guard let text = defaults.string(forKey: Constants.pendingContextKey), !text.isEmpty else { return nil }
        return text
    }

    // MARK: - Screenshot file (broadcast/scroll capture only)

    func writeScreenshot(_ image: UIImage) throws {
        guard let data = image.pngData() else { throw AppGroupError.encodingFailed }
        let url = container.appendingPathComponent(Constants.screenshotFilename)
        try data.write(to: url, options: .atomic)
        NSLog("[Replr][AppGroup] writeScreenshot file: %.0fx%.0f (%d bytes)", image.size.width, image.size.height, data.count)
    }

    func readScreenshot() throws -> UIImage {
        let url = container.appendingPathComponent(Constants.screenshotFilename)
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else { throw AppGroupError.decodingFailed }
        NSLog("[Replr][AppGroup] readScreenshot file: %.0fx%.0f", image.size.width, image.size.height)
        return image
    }

    // MARK: - Capture ready flag (broadcast flow only)

    var isCaptureReady: Bool {
        get { FileManager.default.fileExists(atPath: container.appendingPathComponent(Constants.captureReadyKey).path) }
        set {
            let url = container.appendingPathComponent(Constants.captureReadyKey)
            if newValue { FileManager.default.createFile(atPath: url.path, contents: nil) }
            else { try? FileManager.default.removeItem(at: url) }
        }
    }

    var isBroadcastActive: Bool {
        get { FileManager.default.fileExists(atPath: container.appendingPathComponent(Constants.broadcastActiveKey).path) }
        set {
            let url = container.appendingPathComponent(Constants.broadcastActiveKey)
            if newValue { FileManager.default.createFile(atPath: url.path, contents: nil) }
            else { try? FileManager.default.removeItem(at: url) }
        }
    }
}

enum AppGroupError: Error {
    case encodingFailed
    case decodingFailed
}
