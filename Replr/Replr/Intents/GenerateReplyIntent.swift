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

    func perform() async throws -> some IntentResult {
        ReplyService.bootstrapAuthIfNeeded()
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

        // One-shot: the steer applies to THIS capture only. Without the consume,
        // a Back Tap flow that never reopens the keyboard (e.g. replies viewed in
        // the app) left the steer in the App Group, seasoning every later capture.
        // It stays available to Regenerate via this session's contextHint.
        let context = AppGroupService.shared.consumePendingContext()

        // Tone always comes from the keyboard selection (never the Shortcut), so a
        // Back Tap capture respects whatever tone the user last picked.
        let effectiveTone = AppGroupService.shared.readSelectedTone()
        NSLog("[Replr][Intent] Calling API: tone=%@ (keyboard selection), hasContext=%d", effectiveTone.name, context != nil ? 1 : 0)

        // Use the dating prompt family when the keyboard's persisted mode is dating.
        let generationMode = AppGroupService.shared.selectedInputMode == "dating" ? "dating" : "chat"

        // Fresh capture: drop any prior contact so this capture isn't seasoned with
        // another person's memory before THIS screenshot's contact is identified
        // (resolveContact re-sets it after). Matches the keyboard capture paths —
        // memory re-enters via Regenerate once the contact is known.
        AppGroupService.shared.currentContactID = nil
        let previousContext: String? = nil
        AppGroupService.shared.memoryUsedContactName = nil

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: effectiveTone,
                summary: context,
                previousContext: previousContext,
                mode: generationMode
            )
            NSLog("[Replr][Intent] Got %d replies — saving to App Group", result.replies.count)

            let resolved = resolveContact(from: result)
            let resolvedContactID = resolved.id
            let resolvedContactName = resolved.name

            let thumbnail = CaptureThumbnail.make(image)
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
            if let remaining = result.creditsRemaining {
                AppGroupService.shared.creditBalance = remaining   // server-authoritative
            } else {
                CreditsManager.shared.deduct(required)             // legacy local fallback
            }
            AppGroupService.shared.isGenerating = false
            AppGroupService.shared.appendCaptureSession(session)
            AppGroupService.shared.saveReplies(result.replies)
        } catch ReplyError.insufficientCredits {
            NSLog("[Replr][Intent] server declined: insufficient credits")
            AppGroupService.shared.isGenerating = false
            AppGroupService.shared.saveError("insufficient_credits")
        } catch {
            NSLog("[Replr][Intent] API error: %@", error.localizedDescription)
            AppGroupService.shared.isGenerating = false
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }

}
