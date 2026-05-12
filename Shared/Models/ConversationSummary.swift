import Foundation

struct ConversationSummary: Codable, Identifiable {
    let id: UUID
    var personName: String
    var platform: String
    var notes: String
    var updatedAt: Date
}
