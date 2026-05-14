import ReplayKit
import UIKit

class SampleHandler: RPBroadcastSampleHandler {
    private var didCaptureSingle = false
    private var isScrollMode = false
    private var frames: [UIImage] = []
    private let maxFrames = 6
    private var captureAfter = Date.distantFuture

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        isScrollMode = UserDefaults(suiteName: Constants.appGroupID)?.bool(forKey: Constants.scrollModeKey) ?? false
        didCaptureSingle = false
        frames = []
        if !isScrollMode {
            // Signal CaptureView to show the countdown.
            // Capture fires at 8s: countdown runs 5s, dismisses, user is in chat app for ~3s before capture.
            AppGroupService.shared.isBroadcastActive = true
            captureAfter = Date().addingTimeInterval(8.0)
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        if isScrollMode {
            if frames.count < maxFrames {
                frames.append(image)
            }
        } else {
            guard !didCaptureSingle, Date() >= captureAfter else { return }
            didCaptureSingle = true
            AppGroupService.shared.isBroadcastActive = false
            do {
                try AppGroupService.shared.writeScreenshot(image)
                AppGroupService.shared.isCaptureReady = true
            } catch {
                finishBroadcastWithError(error)
                return
            }
            finishBroadcastWithError(NSError(
                domain: "com.replr.broadcast",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Screenshot captured. Check your Replr keyboard for reply suggestions."]
            ))
        }
    }

    override func broadcastFinished() {
        guard isScrollMode, !frames.isEmpty else { return }
        writeScrollFrames(frames)
    }

    override func broadcastPaused() {}
    override func broadcastResumed() {}

    private func writeScrollFrames(_ frames: [UIImage]) {
        let defaults = UserDefaults(suiteName: Constants.appGroupID)
        defaults?.set(frames.count, forKey: Constants.scrollFrameCountKey)
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupID
        ) else { return }

        for (i, frame) in frames.enumerated() {
            if let data = frame.pngData() {
                let url = container.appendingPathComponent("scroll_frame_\(i).png")
                try? data.write(to: url, options: .atomic)
            }
        }
        defaults?.set(true, forKey: Constants.scrollCaptureReadyKey)
    }
}
