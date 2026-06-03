import Foundation

struct CaptureSession: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let thumbnailData: Data?
    let contextHint: String?
    let generatedReplies: [String]
    var selectedReply: String?
    var llmSummary: String?
    var contactID: UUID?
    var contactName: String?

    // Capture intelligence — what the AI actually used
    var toneName: String?          // tone name selected at capture time
    var previousContext: String?   // memory summaries fed to the AI
    var modelUsed: String?         // model identifier used for this capture
}
