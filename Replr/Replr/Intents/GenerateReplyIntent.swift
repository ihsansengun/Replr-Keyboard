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

        // Fetch memories for the current confirmed contact
        let previousContext: String?
        if let contactID = AppGroupService.shared.currentContactID {
            let summaries = AppGroupService.shared.recentSummaries(forContactID: contactID, limit: 10)
            previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
        } else {
            previousContext = nil
        }

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone.tone,
                summary: context,
                previousContext: previousContext,
                model: "claude",
                transactionId: txID
            )
            NSLog("[Replr][Intent] Got %d replies — saving to App Group", result.replies.count)

            // Resolve or create contact — auto-switch if LLM detects a different person
            let resolvedContactID: UUID?
            let resolvedContactName: String?
            let isGroupOrUnknown = result.contactName == nil
                || result.contactName == "Unknown"
                || result.contactName?.isEmpty == true
                || result.contactName?.hasPrefix("Group:") == true
            if isGroupOrUnknown {
                resolvedContactID = nil
                resolvedContactName = result.contactName
            } else if let existingID = AppGroupService.shared.currentContactID,
                      let existingContact = AppGroupService.shared.loadContacts()
                          .first(where: { $0.id == existingID }),
                      let llmName = result.contactName,
                      existingContact.displayName.trimmingCharacters(in: .whitespaces).lowercased()
                          == llmName.trimmingCharacters(in: .whitespaces).lowercased() {
                // Same contact — reuse canonical display name
                resolvedContactID = existingID
                resolvedContactName = existingContact.displayName
            } else if let name = result.contactName {
                // Different contact or no existing contact — find or create, switch currentContactID
                let contact = AppGroupService.shared.findContacts(named: name).first
                    ?? AppGroupService.shared.createContact(displayName: name)
                AppGroupService.shared.currentContactID = contact.id
                resolvedContactID = contact.id
                resolvedContactName = contact.displayName
            } else {
                resolvedContactID = nil
                resolvedContactName = nil
            }

            let thumbnail = makeThumbnail(image)
            let session = CaptureSession(
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
            AppGroupService.shared.appendCaptureSession(session)
            AppGroupService.shared.saveReplies(result.replies)
        } catch {
            NSLog("[Replr][Intent] API error: %@", error.localizedDescription)
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
