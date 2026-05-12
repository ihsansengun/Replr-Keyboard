import ReplayKit
import UIKit

class SampleHandler: RPBroadcastSampleHandler {
    private var didCaptureSingle = false
    private var isScrollMode = false
    private var frames: [UIImage] = []
    private let maxFrames = 6

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        isScrollMode = UserDefaults(suiteName: Constants.appGroupID)?.bool(forKey: Constants.scrollModeKey) ?? false
        didCaptureSingle = false
        frames = []
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
            guard !didCaptureSingle else { return }
            didCaptureSingle = true
            do {
                try AppGroupService.shared.writeScreenshot(image)
                AppGroupService.shared.isCaptureReady = true
            } catch {
                finishBroadcastWithError(error)
                return
            }
            finishBroadcastWithError(nil)
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
