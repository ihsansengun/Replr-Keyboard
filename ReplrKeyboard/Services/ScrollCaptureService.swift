import Foundation
import UIKit

final class ScrollCaptureService {
    static let shared = ScrollCaptureService()

    func startScrollMode() {
        UserDefaults(suiteName: Constants.appGroupID)?.set(true, forKey: Constants.scrollModeKey)
        UserDefaults(suiteName: Constants.appGroupID)?.set(false, forKey: Constants.scrollCaptureReadyKey)
    }

    func stopScrollMode() {
        UserDefaults(suiteName: Constants.appGroupID)?.set(false, forKey: Constants.scrollModeKey)
    }

    func waitForScrollCapture(timeout: TimeInterval = 15) async throws -> [UIImage] {
        let deadline = Date().addingTimeInterval(timeout)
        let defaults = UserDefaults(suiteName: Constants.appGroupID)

        while Date() < deadline {
            if defaults?.bool(forKey: Constants.scrollCaptureReadyKey) == true {
                defaults?.set(false, forKey: Constants.scrollCaptureReadyKey)
                return try readScrollFrames()
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw CaptureError.timeout
    }

    private func readScrollFrames() throws -> [UIImage] {
        let defaults = UserDefaults(suiteName: Constants.appGroupID)
        let count = defaults?.integer(forKey: Constants.scrollFrameCountKey) ?? 0
        guard count > 0 else { throw AppGroupError.decodingFailed }

        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupID
        ) else { throw AppGroupError.decodingFailed }

        return try (0..<count).map { i in
            let url = container.appendingPathComponent("scroll_frame_\(i).png")
            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else { throw AppGroupError.decodingFailed }
            return image
        }
    }
}
