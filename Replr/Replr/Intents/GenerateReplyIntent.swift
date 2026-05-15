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

    @Parameter(title: "Tone", default: .casual)
    var tone: ReplyTone

    func perform() async throws -> some IntentResult {
        NSLog("[Replr][Intent] GenerateReplyIntent fired")

        guard let image = UIImage(data: screenshot.data) else {
            NSLog("[Replr][Intent] Could not decode screenshot data")
            AppGroupService.shared.saveError("Could not read the screenshot image.")
            return .result()
        }

        NSLog("[Replr][Intent] Image loaded: %.0fx%.0f", image.size.width, image.size.height)

        let context = AppGroupService.shared.readPendingContext()
        let txID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)
        NSLog("[Replr][Intent] Calling API: tone=%@, hasContext=%d", tone.rawValue, context != nil ? 1 : 0)

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone.tone,
                summary: context,
                previousContext: nil,
                model: "claude",
                transactionId: txID
            )
            NSLog("[Replr][Intent] Got %d replies — saving to App Group", result.replies.count)
            AppGroupService.shared.saveReplies(result.replies)
        } catch {
            NSLog("[Replr][Intent] API error: %@", error.localizedDescription)
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }
}
