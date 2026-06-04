import AppIntents
import UIKit

struct GenerateReplyIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Reply"
    static var description = IntentDescription("Generates reply suggestions from a chat screenshot. Chain with 'Take Screenshot' in Shortcuts for a one-tap flow.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Screenshot",
        supportedTypeIdentifiers: ["public.image"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    @Parameter(title: "Tone", default: .friendly)
    var tone: ReplyTone

    func perform() async throws -> some IntentResult {
        NSLog("[Replr][Intent] GenerateReplyIntent fired")
        AppGroupService.shared.lastIntentFiredAt = Date()

        // Credit gate
        let balance = AppGroupService.shared.effectiveCreditBalance
        let required = AppGroupService.shared.devMode ? 0
            : CreditsManager.shared.creditsRequired(for: AppGroupService.shared.selectedModel)
        guard balance >= required else {
            NSLog("[Replr][Intent] insufficient credits (%d required, %d available)", required, balance)
            AppGroupService.shared.saveError("insufficient_credits")
            return .result()
        }

        guard let image = UIImage(data: screenshot.data) else {
            NSLog("[Replr][Intent] Could not decode screenshot data")
            AppGroupService.shared.saveError("Could not read the screenshot image.")
            return .result()
        }

        NSLog("[Replr][Intent] Image loaded: %.0fx%.0f", image.size.width, image.size.height)

        // Persist screenshot so the keyboard can regenerate without re-capturing
        try? AppGroupService.shared.writeScreenshot(image)

        AppGroupService.shared.isGenerating = true

        let context = AppGroupService.shared.readPendingContext()

        // Always use the tone selected in the keyboard — the Shortcut parameter is
        // ignored because it defaults to Friendly and users never edit it manually.
        let effectiveTone = AppGroupService.shared.readSelectedTone()
        NSLog("[Replr][Intent] Calling API: tone=%@ (keyboard selection), hasContext=%d", effectiveTone.name, context != nil ? 1 : 0)

        // Fetch memories for the current confirmed contact
        let previousContext: String?
        if AppGroupService.shared.memoryEnabled,
           let contactID = AppGroupService.shared.currentContactID {
            let summaries = AppGroupService.shared.recentSummaries(
                forContactID: contactID,
                limit: AppGroupService.shared.memoryDepth
            )
            previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
        } else {
            previousContext = nil
        }

        if previousContext != nil,
           let contactID = AppGroupService.shared.currentContactID,
           let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == contactID }) {
            AppGroupService.shared.memoryUsedContactName = contact.displayName
        } else {
            AppGroupService.shared.memoryUsedContactName = nil
        }

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: effectiveTone,
                summary: context,
                previousContext: previousContext
            )
            NSLog("[Replr][Intent] Got %d replies — saving to App Group", result.replies.count)

            let resolved = resolveContact(from: result)
            let resolvedContactID = resolved.id
            let resolvedContactName = resolved.name

            let thumbnail = makeThumbnail(image)
            var session = CaptureSession(
                id: UUID(),
                timestamp: Date(),
                thumbnailData: thumbnail,
                contextHint: context,
                generatedReplies: result.replies,
                selectedReply: nil,
                llmSummary: result.summary,
                contactID: resolvedContactID,
                contactName: resolvedContactName
            )
            session.toneName = effectiveTone.name
            session.previousContext = previousContext
            session.modelUsed = AppGroupService.shared.selectedModel
            session.inputTokens = result.inputTokens
            session.outputTokens = result.outputTokens
            session.costUsd = result.costUsd
            CreditsManager.shared.deduct(required)
            AppGroupService.shared.isGenerating = false
            AppGroupService.shared.appendCaptureSession(session)
            AppGroupService.shared.saveReplies(result.replies)
        } catch {
            NSLog("[Replr][Intent] API error: %@", error.localizedDescription)
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
