import Foundation
import UIKit

struct ReplyRequest: Codable {
    let screenshotBase64: String
    let tone: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
    let aboutUser: String?
}

struct ReplyEmailRequest: Codable {
    let emailText: String
    let tone: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
    let aboutUser: String?
}

struct ReplyResponse: Codable {
    let replies: [String]
    let summary: String?
    let contactName: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let costUsd: Double?
}

struct ReplyResult {
    let replies: [String]
    let summary: String?
    let contactName: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let costUsd: Double?
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
            userId: AppGroupService.shared.userID(),
            aboutUser: AppGroupService.shared.aboutUser.isEmpty ? nil : AppGroupService.shared.aboutUser
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
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName, inputTokens: decoded.inputTokens, outputTokens: decoded.outputTokens, costUsd: decoded.costUsd)
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
            userId: AppGroupService.shared.userID(),
            aboutUser: AppGroupService.shared.aboutUser.isEmpty ? nil : AppGroupService.shared.aboutUser
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
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName, inputTokens: decoded.inputTokens, outputTokens: decoded.outputTokens, costUsd: decoded.costUsd)
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
            let aboutUser: String?
        }

        let scrollBody = ScrollRequest(
            screenshots: frames,
            tone: tone.instruction,
            summary: summary,
            previousContext: previousContext,
            model: AppGroupService.shared.selectedModel,
            userId: AppGroupService.shared.userID(),
            aboutUser: AppGroupService.shared.aboutUser.isEmpty ? nil : AppGroupService.shared.aboutUser
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
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName, inputTokens: decoded.inputTokens, outputTokens: decoded.outputTokens, costUsd: decoded.costUsd)
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
        // Strategy: downscale 3× screenshots to 2× then JPEG 92%.
        //
        // Why this is safe:
        //   Claude Sonnet caps at 1,568 tokens for any image > ~750×1,050px.
        //   GPT uses the same 8 tiles for any portrait screenshot.
        //   So 3× (1179×2556) and 2× (786×1704) produce identical token counts —
        //   the extra resolution is discarded by the model anyway.
        //
        // Why this matters:
        //   3× PNG: ~2.5 MB → base64 ~3.3 MB → ~1–2s upload on LTE
        //   2× JPEG 92%: ~180 KB → base64 ~240 KB → ~90ms upload on LTE
        //   ~13× smaller payload, visually identical to PNG for text/emoji.

        let originalScale = max(image.scale, 1.0)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // renderer works in raw pixels

        // Cap at 2× logical resolution — no upscaling for images already ≤ 2×
        let targetScale = min(originalScale, 2.0)
        let targetSize = CGSize(
            width: floor(image.size.width * targetScale),
            height: floor(image.size.height * targetScale)
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // JPEG 92% — visually lossless for text, much smaller than PNG
        return resized.jpegData(compressionQuality: 0.92)
            ?? resized.pngData()
            ?? (image.pngData() ?? Data())
    }
}
