import AppIntents
import Photos
import UIKit

struct QuickReplyIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Reply"
    static var description = IntentDescription("Reads your latest chat screenshot and generates reply suggestions in the Replr keyboard. No setup needed.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        ReplyService.bootstrapAuthIfNeeded()
        NSLog("[Replr][QuickReply] fired")

        // Credit gate — mirrors GenerateReplyIntent (the server enforces too once
        // the account is server-managed; this avoids a doomed round-trip).
        let balance = AppGroupService.shared.effectiveCreditBalance
        let required = AppGroupService.shared.devMode ? 0
            : CreditsManager.shared.creditsRequired(for: AppGroupService.shared.selectedModel)
        guard balance >= required else {
            NSLog("[Replr][QuickReply] insufficient credits (%d required, %d available)", required, balance)
            AppGroupService.shared.saveError("insufficient_credits")
            return .result()
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            NSLog("[Replr][QuickReply] No Photos access")
            AppGroupService.shared.saveError("Allow photo access in Settings → Apps → Replr → Photos, then try again.")
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
            NSLog("[Replr][QuickReply] No screenshot found")
            AppGroupService.shared.saveError("No screenshot found. Take a screenshot of your chat first.")
            return .result()
        }
        NSLog("[Replr][QuickReply] Found screenshot: creationDate=%@", asset.creationDate.map { "\($0)" } ?? "nil")

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
                } else if (info?[PHImageErrorKey] as? Error) != nil {
                    continuation.resume(throwing: QuickReplyError.imageLoadFailed)
                }
                // else: degraded frame — wait for full-quality delivery
            }
        }

        NSLog("[Replr][QuickReply] Image loaded: %.0fx%.0f", image.size.width, image.size.height)

        let tone = AppGroupService.shared.readSelectedTone()
        NSLog("[Replr][QuickReply] Calling API: tone=%@", tone.name)

        // Use the dating prompt family when the keyboard's persisted mode is dating.
        let generationMode = AppGroupService.shared.selectedInputMode == "dating" ? "dating" : "chat"

        // Fresh capture: drop any prior contact so this capture isn't seasoned with
        // another person's memory before THIS screenshot's contact is identified
        // (resolveContact re-sets it after). Matches the keyboard capture paths.
        AppGroupService.shared.currentContactID = nil
        let previousContext: String? = nil
        AppGroupService.shared.memoryUsedContactName = nil

        AppGroupService.shared.isGenerating = true

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone,
                summary: nil,
                previousContext: previousContext,
                mode: generationMode
            )
            NSLog("[Replr][QuickReply] Got %d replies — saving to App Group", result.replies.count)

            let resolved = resolveContact(from: result)
            let resolvedContactID = resolved.id
            let resolvedContactName = resolved.name

            let thumbnail = makeThumbnail(image)
            var session = CaptureSession(
                id: UUID(),
                timestamp: Date(),
                thumbnailData: thumbnail,
                contextHint: nil,
                generatedReplies: result.replies,
                selectedReply: nil,
                llmSummary: result.summary,
                contactID: resolvedContactID,
                contactName: resolvedContactName
            )
            session.toneName = tone.name
            session.previousContext = previousContext
            session.modelUsed = AppGroupService.shared.selectedModel
            session.inputTokens = result.inputTokens
            session.outputTokens = result.outputTokens
            session.costUsd = result.costUsd
            if let remaining = result.creditsRemaining {
                AppGroupService.shared.creditBalance = remaining   // server-authoritative
            } else {
                CreditsManager.shared.deduct(required)             // legacy local fallback
            }
            AppGroupService.shared.isGenerating = false
            AppGroupService.shared.appendCaptureSession(session)
            AppGroupService.shared.saveReplies(result.replies)
        } catch ReplyError.insufficientCredits {
            NSLog("[Replr][QuickReply] server declined: insufficient credits")
            AppGroupService.shared.isGenerating = false
            AppGroupService.shared.saveError("insufficient_credits")
        } catch {
            NSLog("[Replr][QuickReply] API error: %@", error.localizedDescription)
            AppGroupService.shared.isGenerating = false
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }

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

enum QuickReplyError: Error {
    case imageLoadFailed
}
