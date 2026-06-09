import Foundation
import Security
import UIKit

struct ReplyRequest: Codable {
    let screenshotBase64: String
    let tone: String
    let toneName: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
    let aboutUser: String?
}

struct ReplyEmailRequest: Codable {
    let emailText: String
    let tone: String
    let toneName: String
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
    /// Authoritative balance after a server-side charge. Present only for
    /// server-managed users (signed in + migrated); nil → legacy local deduction.
    let creditsRemaining: Int?
}

struct ReplyResult {
    let replies: [String]
    let summary: String?
    let contactName: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let costUsd: Double?
    let creditsRemaining: Int?
}

/// Result of a dev model-tester ping (ModelPickerView → "Test all models").
struct ModelTestResult {
    let modelID: String
    let ok: Bool
    let latencyMs: Int
    let message: String   // "OK" or the raw backend error detail
}

/// Decodes the backend's `{ error, detail }` error envelope so the tester can show WHY a model failed.
private struct ErrorDetailBody: Decodable { let error: String?; let detail: String? }

final class ReplyService {
    static let shared = ReplyService()
    nonisolated(unsafe) private(set) static var authToken: String?

    /// Called when the backend returns 401. Set by AuthService on the Replr target.
    /// Other targets (keyboard, broadcast) leave this nil.
    static var onUnauthorized: (@MainActor () -> Void)? = nil

    private let session: URLSession
    private let backendURL: URL

    init(session: URLSession = .shared) {
        self.session = session
        self.backendURL = URL(string: Constants.backendURL + "/reply")!
    }

    /// Sets the authentication token. Called only from AuthService on the main thread.
    static func setAuthToken(_ token: String?) {
        authToken = token
    }

    /// Bootstraps the session token from Keychain when the app process hasn't initialized
    /// AuthService (e.g. AppIntents running in a separate process). No-op if token already set.
    static func bootstrapAuthIfNeeded() {
        guard authToken == nil else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.ihsan.replr",
            kSecAttrAccount as String: "replr.auth.sessionToken",
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return }
        setAuthToken(token)
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
            toneName: tone.name,
            summary: summary,
            previousContext: previousContext,
            model: AppGroupService.shared.selectedModel,
            userId: AppGroupService.shared.userID(),
            aboutUser: AppGroupService.shared.aboutUser.isEmpty ? nil : AppGroupService.shared.aboutUser
        )

        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReplyError.invalidResponse }
        if http.statusCode == 401 {
            Task { @MainActor in ReplyService.onUnauthorized?() }
            throw ReplyError.serverError(401)
        }
        if http.statusCode == 402 { throw ReplyError.insufficientCredits }
        if http.statusCode == 429 { throw ReplyError.rateLimitReached }
        guard http.statusCode == 200 else { throw ReplyError.serverError(http.statusCode) }

        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName, inputTokens: decoded.inputTokens, outputTokens: decoded.outputTokens, costUsd: decoded.costUsd, creditsRemaining: decoded.creditsRemaining)
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
            toneName: tone.name,
            summary: summary,
            previousContext: previousContext,
            model: AppGroupService.shared.selectedModel,
            userId: AppGroupService.shared.userID(),
            aboutUser: AppGroupService.shared.aboutUser.isEmpty ? nil : AppGroupService.shared.aboutUser
        )

        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReplyError.invalidResponse }
        if http.statusCode == 401 {
            Task { @MainActor in ReplyService.onUnauthorized?() }
            throw ReplyError.serverError(401)
        }
        if http.statusCode == 402 { throw ReplyError.insufficientCredits }
        if http.statusCode == 429 { throw ReplyError.rateLimitReached }
        guard http.statusCode == 200 else { throw ReplyError.serverError(http.statusCode) }

        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName, inputTokens: decoded.inputTokens, outputTokens: decoded.outputTokens, costUsd: decoded.costUsd, creditsRemaining: decoded.creditsRemaining)
    }

    /// Dev model-tester (ModelPickerView): pings the backend with a fixed sample using an EXPLICIT
    /// model id and surfaces OK + latency, or the raw error detail. Never throws — returns a result.
    func testModel(_ modelID: String) async -> ModelTestResult {
        let start = Date()
        func ms() -> Int { Int(Date().timeIntervalSince(start) * 1000) }
        let body = ReplyEmailRequest(
            emailText: "Hey, are you free to chat tomorrow about the report?",
            tone: "natural", toneName: "Natural",
            summary: nil, previousContext: nil,
            model: modelID, userId: AppGroupService.shared.userID(),
            aboutUser: nil
        )
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        request.timeoutInterval = 45
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ModelTestResult(modelID: modelID, ok: false, latencyMs: ms(), message: "No HTTP response")
            }
            if http.statusCode == 401 {
                Task { @MainActor in ReplyService.onUnauthorized?() }
                return ModelTestResult(modelID: modelID, ok: false, latencyMs: ms(), message: "HTTP 401: Unauthorized")
            }
            if http.statusCode == 200 {
                return ModelTestResult(modelID: modelID, ok: true, latencyMs: ms(), message: "OK")
            }
            let parsed = try? JSONDecoder().decode(ErrorDetailBody.self, from: data)
            let detail = parsed?.detail ?? parsed?.error ?? String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            return ModelTestResult(modelID: modelID, ok: false, latencyMs: ms(), message: "HTTP \(http.statusCode): \(detail)")
        } catch {
            return ModelTestResult(modelID: modelID, ok: false, latencyMs: ms(), message: error.localizedDescription)
        }
    }

}

enum ReplyError: LocalizedError {
    case encodingFailed
    case invalidResponse
    case rateLimitReached
    case insufficientCredits
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:      return "Couldn't process the screenshot."
        case .invalidResponse:     return "Something went wrong. Tap Try again."
        case .rateLimitReached:    return "Daily limit reached. Try again tomorrow."
        // "out of credits" is the sentinel ErrorPanelView maps to its credits
        // category (top-up CTA) — keep that phrase if rewording.
        case .insufficientCredits: return "You're out of credits. Top up in the Replr app."
        case .serverError:         return "Something went wrong. Tap Try again."
        }
    }
}

// MARK: - Helpers

private extension ReplyService {
    func addAuthHeader(to request: inout URLRequest) {
        if let token = ReplyService.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
