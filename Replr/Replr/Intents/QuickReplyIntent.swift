import AppIntents
import Photos
import UIKit

struct QuickReplyIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Reply"
    static var description = IntentDescription("Reads your latest chat screenshot and generates reply suggestions in the Replr keyboard. No setup needed.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        NSLog("[Replr][QuickReply] fired")

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            NSLog("[Replr][QuickReply] No Photos access")
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
                } else if let image {
                    _ = image // degraded — wait for full quality
                } else {
                    continuation.resume(throwing: QuickReplyError.imageLoadFailed)
                }
            }
        }

        NSLog("[Replr][QuickReply] Image loaded: %.0fx%.0f", image.size.width, image.size.height)

        let tone = AppGroupService.shared.readSelectedTone()
        let txID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)
        NSLog("[Replr][QuickReply] Calling API: tone=%@", tone.name)

        do {
            let replies = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone,
                summary: nil,
                model: "claude",
                transactionId: txID
            )
            NSLog("[Replr][QuickReply] Got %d replies — saving to App Group", replies.count)
            AppGroupService.shared.saveReplies(replies)
        } catch {
            NSLog("[Replr][QuickReply] API error: %@", error.localizedDescription)
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }
}

enum QuickReplyError: Error {
    case imageLoadFailed
}
