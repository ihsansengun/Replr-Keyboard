import Foundation
import UIKit

final class CaptureService {
    static let shared = CaptureService()

    func resetCaptureFlag() {
        AppGroupService.shared.isCaptureReady = false
    }

    func waitForCapture(timeout: TimeInterval = 25) async throws -> UIImage {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if AppGroupService.shared.isCaptureReady {
                AppGroupService.shared.isCaptureReady = false
                return try AppGroupService.shared.readScreenshot()
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw CaptureError.timeout
    }
}

enum CaptureError: LocalizedError {
    case timeout

    var errorDescription: String? {
        "Capture timed out. Try again."
    }
}
