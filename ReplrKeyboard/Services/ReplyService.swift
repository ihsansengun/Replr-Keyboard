import Foundation
import UIKit

struct ReplyRequest: Codable {
    let screenshotBase64: String
    let tone: String
    let summary: String?
    let model: String
    let userId: String
    let transactionId: String?
}

struct ReplyResponse: Codable {
    let replies: [String]
}

final class ReplyService {
    static let shared = ReplyService()

    private let session: URLSession
    private let backendURL: URL

    init(session: URLSession = .shared) {
        self.session = session
        self.backendURL = URL(string: Constants.backendURL + "/reply")!
    }

    func generateReplies(
        screenshot: UIImage,
        tone: Tone,
        summary: String?,
        model: String,
        transactionId: String?
    ) async throws -> [String] {
        guard let pngData = screenshot.pngData() else { throw ReplyError.encodingFailed }
        let base64 = pngData.base64EncodedString()

        let body = ReplyRequest(
            screenshotBase64: base64,
            tone: tone.instruction,
            summary: summary,
            model: model,
            userId: AppGroupService.shared.userID(),
            transactionId: transactionId
        )

        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw ReplyError.invalidResponse }

        if http.statusCode == 429 { throw ReplyError.rateLimitReached }
        guard http.statusCode == 200 else { throw ReplyError.serverError(http.statusCode) }

        return try JSONDecoder().decode(ReplyResponse.self, from: data).replies
    }
}

enum ReplyError: LocalizedError {
    case encodingFailed
    case invalidResponse
    case rateLimitReached
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:      return "Couldn't process the screenshot."
        case .invalidResponse:     return "Something went wrong. Tap Capture to retry."
        case .rateLimitReached:    return "Daily limit reached. Upgrade to premium for unlimited replies."
        case .serverError:         return "Something went wrong. Tap Capture to retry."
        }
    }
}
