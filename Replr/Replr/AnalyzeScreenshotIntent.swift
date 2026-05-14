import AppIntents
import UIKit

struct AnalyzeScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Analyze Screenshot"
    static var description = IntentDescription("Analyzes a chat screenshot and prepares reply suggestions in your Replr keyboard.")

    @Parameter(
        title: "Screenshot",
        description: "The chat screenshot to analyze",
        supportedTypeIdentifiers: ["public.image"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile?

    static var parameterSummary: some ParameterSummary {
        Summary("Analyze \(\.$screenshot)")
    }

    func perform() async throws -> some IntentResult {
        NSLog("[Replr][Intent] perform() called")

        guard let screenshot else {
            NSLog("[Replr][Intent] ERROR: screenshot parameter is nil")
            AppGroupService.shared.saveError("No screenshot received. Check your Shortcut setup.")
            return .result()
        }
        NSLog("[Replr][Intent] screenshot filename=%@ dataBytes=%d", screenshot.filename ?? "nil", screenshot.data.count)

        guard let image = UIImage(data: screenshot.data) else {
            NSLog("[Replr][Intent] ERROR: could not decode UIImage from data")
            AppGroupService.shared.saveError("Could not read the screenshot image.")
            return .result()
        }
        NSLog("[Replr][Intent] decoded image size=%@ scale=%.1f", NSCoder.string(for: image.size), image.scale)

        let tone = AppGroupService.shared.readSelectedTone()
        let txID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)
        NSLog("[Replr][Intent] calling API: tone=%@ txID=%@", tone.name, txID ?? "nil")

        do {
            let replies = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone,
                summary: nil,
                model: "claude",
                transactionId: txID
            )
            NSLog("[Replr][Intent] got %d replies, saving to App Group", replies.count)
            AppGroupService.shared.saveReplies(replies)
        } catch {
            NSLog("[Replr][Intent] API error: %@", error.localizedDescription)
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }
}
