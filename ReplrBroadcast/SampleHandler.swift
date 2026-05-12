import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    private var didCapture = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {}
    override func broadcastPaused() {}
    override func broadcastResumed() {}

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, !didCapture else { return }
        didCapture = true

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            finishBroadcastWithError(NSError(domain: "Replr", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No image buffer"]))
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            finishBroadcastWithError(NSError(domain: "Replr", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "CIContext failed"]))
            return
        }

        let uiImage = UIImage(cgImage: cgImage)
        do {
            try AppGroupService.shared.writeScreenshot(uiImage)
            AppGroupService.shared.isCaptureReady = true
        } catch {
            finishBroadcastWithError(error)
            return
        }

        finishBroadcastWithError(nil)
    }

    override func broadcastFinished() {}
}
