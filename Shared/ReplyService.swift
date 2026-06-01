import Foundation
import UIKit

struct ReplyRequest: Codable {
    let screenshotBase64: String
    let tone: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
}

struct ReplyEmailRequest: Codable {
    let emailText: String
    let tone: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
}

struct ReplyResponse: Codable {
    let replies: [String]
    let summary: String?
    let contactName: String?
}

struct ReplyResult {
    let replies: [String]
    let summary: String?
    let contactName: String?
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
        previousContext: String?
    ) async throws -> ReplyResult {
        let imageData = compressForUpload(screenshot)
        guard !imageData.isEmpty else { throw ReplyError.encodingFailed }
        let base64 = imageData.base64EncodedString()

        let body = ReplyRequest(
            screenshotBase64: base64,
            tone: tone.instruction,
            summary: summary,
            previousContext: previousContext,
            model: AppGroupService.shared.selectedModel,
            userId: AppGroupService.shared.userID()
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

        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName)
    }

    func generateRepliesFromEmail(
        emailText: String,
        tone: Tone,
        summary: String?,
        previousContext: String?
    ) async throws -> ReplyResult {
        let body = ReplyEmailRequest(
            emailText: emailText,
            tone: tone.instruction,
            summary: summary,
            previousContext: previousContext,
            model: AppGroupService.shared.selectedModel,
            userId: AppGroupService.shared.userID()
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

        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName)
    }

    func generateRepliesFromScroll(
        screenshots: [UIImage],
        tone: Tone,
        summary: String?,
        previousContext: String?
    ) async throws -> ReplyResult {
        let frames = screenshots.prefix(6).map { compressForUpload($0).base64EncodedString() }
        guard !frames.isEmpty else { throw ReplyError.encodingFailed }

        struct ScrollRequest: Encodable {
            let screenshots: [String]
            let tone: String
            let summary: String?
            let previousContext: String?
            let model: String
            let userId: String
        }

        let scrollBody = ScrollRequest(
            screenshots: frames,
            tone: tone.instruction,
            summary: summary,
            previousContext: previousContext,
            model: AppGroupService.shared.selectedModel,
            userId: AppGroupService.shared.userID()
        )

        let scrollURL = URL(string: Constants.backendURL + "/reply/scroll")!
        var request = URLRequest(url: scrollURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONEncoder().encode(scrollBody)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReplyError.invalidResponse }
        if http.statusCode == 429 { throw ReplyError.rateLimitReached }
        guard http.statusCode == 200 else { throw ReplyError.serverError(http.statusCode) }

        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName)
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

// MARK: - Image preprocessing

private extension ReplyService {
    func compressForUpload(_ image: UIImage) -> Data {
        // PNG: lossless — preserves exact text, emoji and colours the LLM needs to read.
        // Payload is larger but quality is critical for reply accuracy.
        image.pngData() ?? Data()
    }
}
