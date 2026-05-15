import Foundation

struct CaptureSession: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let thumbnailData: Data?      // ~30 KB JPEG of the screenshot
    let contextHint: String?      // text from "Use as context" if provided
    let generatedReplies: [String]
    var selectedReply: String?    // set when user taps Use on a reply card
    var llmSummary: String?       // one-line summary extracted by the LLM
}
