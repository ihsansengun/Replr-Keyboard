import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    private var didCapture = false

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
        guard
            let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
            let pngData = UIImage(cgImage: cgImage).pngData()
        else {
            finishBroadcastWithError(NSError(domain: "Replr", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Image conversion failed"]))
            return
        }

        do {
            let service = AppGroupService.shared
            try service.writeScreenshot(UIImage(data: pngData)!)
            service.isCaptureReady = true
        } catch {
            finishBroadcastWithError(error)
            return
        }

        finishBroadcastWithError(nil)
    }
}
