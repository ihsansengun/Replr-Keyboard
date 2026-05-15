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
}
