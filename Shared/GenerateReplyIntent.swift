import AppIntents
import Photos
import UIKit

struct GenerateReplyIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Reply"
    static var description = IntentDescription("Reads your latest chat screenshot and prepares reply suggestions in the Replr keyboard.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        NSLog("[Replr][Intent] GenerateReplyIntent fired")
        AppGroupService.shared.isGenerating = true
        defer { AppGroupService.shared.isGenerating = false }

        let tone = AppGroupService.shared.readSelectedTone()
        let context = AppGroupService.shared.readPendingContext()
        let txID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)

        // Build previousContext from recent sessions (last 4 hours)
        let recentSummaries = AppGroupService.shared.activeSessionSummaries()
        let previousContext: String? = recentSummaries.isEmpty ? nil : recentSummaries.joined(separator: "\n")

        // Email tone: read from clipboard
        if tone.name.lowercased() == "email" {
            let clipboardText = UIPasteboard.general.string ?? ""
            guard !clipboardText.trimmingCharacters(in: .whitespaces).isEmpty else {
                NSLog("[Replr][Intent] Email tone but clipboard is empty")
                AppGroupService.shared.saveError("Copy the email text first, then triple-tap to generate a reply.")
                return .result()
            }
            NSLog("[Replr][Intent] Email mode — clipboard length: %d", clipboardText.count)
            do {
                let result = try await ReplyService.shared.generateRepliesFromEmail(
                    emailText: clipboardText,
                    tone: tone,
                    summary: context,
                    previousContext: previousContext,
                    model: "claude",
                    transactionId: txID
                )
                NSLog("[Replr][Intent] Got %d email replies", result.replies.count)
                let session = CaptureSession(
                    id: UUID(),
                    timestamp: Date(),
                    thumbnailData: nil,
                    contextHint: context,
                    generatedReplies: result.replies,
                    selectedReply: nil,
                    llmSummary: result.summary
                )
                AppGroupService.shared.appendCaptureSession(session)
                AppGroupService.shared.saveReplies(result.replies)
            } catch {
                NSLog("[Replr][Intent] Email API error: %@", error.localizedDescription)
                AppGroupService.shared.saveError(error.localizedDescription)
            }
            return .result()
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        NSLog("[Replr][Intent] Photos auth status: %d", status.rawValue)

        guard status == .authorized || status == .limited else {
            NSLog("[Replr][Intent] No Photos access — saving error")
            AppGroupService.shared.saveError("Allow photo access in Settings → Replr → Photos, then try again.")
            return .result()
        }

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 1
        opts.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        guard let asset = PHAsset.fetchAssets(with: .image, options: opts).firstObject else {
            NSLog("[Replr][Intent] No screenshot found in Photos")
            AppGroupService.shared.saveError("No screenshot found. Take a screenshot of your chat first.")
            return .result()
        }
        NSLog("[Replr][Intent] Found screenshot: creationDate=%@", asset.creationDate.map { "\($0)" } ?? "nil")

        let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            let reqOpts = PHImageRequestOptions()
            reqOpts.deliveryMode = .highQualityFormat
            reqOpts.isNetworkAccessAllowed = false
            reqOpts.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: reqOpts
            ) { image, info in
                if let image, (info?[PHImageResultIsDegradedKey] as? Bool) != true {
                    continuation.resume(returning: image)
                } else if image != nil {
                    // degraded delivery — Photos will call back with full quality, discard this
                } else if (info?[PHImageErrorKey] as? Error) != nil || (info?[PHImageResultIsDegradedKey] as? Bool) != true {
                    continuation.resume(throwing: GenerateReplyError.imageLoadFailed)
                }
                // else: nil with degraded flag — mid-flight, wait for next callback
            }
        }

        NSLog("[Replr][Intent] Image loaded: %.0fx%.0f", image.size.width, image.size.height)
        NSLog("[Replr][Intent] Calling API: tone=%@, hasContext=%d, hasPreviousContext=%d",
              tone.name, context != nil ? 1 : 0, previousContext != nil ? 1 : 0)

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone,
                summary: context,
                previousContext: previousContext,
                model: "claude",
                transactionId: txID
            )
            NSLog("[Replr][Intent] Got %d replies — saving to App Group", result.replies.count)
            let thumbnail = makeThumbnail(image)
            let session = CaptureSession(
                id: UUID(),
                timestamp: Date(),
                thumbnailData: thumbnail,
                contextHint: context,
                generatedReplies: result.replies,
                selectedReply: nil,
                llmSummary: result.summary
            )
            AppGroupService.shared.appendCaptureSession(session)
            AppGroupService.shared.saveReplies(result.replies)
        } catch {
            NSLog("[Replr][Intent] API error: %@", error.localizedDescription)
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }

    // Scale screenshot down to ~80px wide JPEG for storage in App Group
    private func makeThumbnail(_ image: UIImage) -> Data? {
        let targetWidth: CGFloat = 80
        guard image.size.width > 0 else { return nil }
        let scale = targetWidth / image.size.width
        let size = CGSize(width: targetWidth, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let thumb = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return thumb.jpegData(compressionQuality: 0.4)
    }
}

enum GenerateReplyError: Error {
    case imageLoadFailed
}
