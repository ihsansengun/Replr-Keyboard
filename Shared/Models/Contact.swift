import Foundation

struct Contact: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
}
