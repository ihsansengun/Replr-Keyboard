import Foundation

/// Backend credits API client. App target only — the keyboard reads the balance
/// from the App Group; the app and intents are the only writers.
enum CreditsService {
    struct BalanceResponse: Decodable {
        let balance: Int
        let serverManaged: Bool?
    }

    struct GrantResponse: Decodable {
        let balance: Int
        let granted: Bool?
        let migrated: Bool?
    }

    enum CreditsError: Error {
        case notSignedIn
        case server(Int)
    }

    /// nil when the server doesn't manage this user yet (no migrate/redeem has happened).
    static func fetchBalance() async throws -> Int? {
        let res: BalanceResponse = try await send(request(path: "/credits", method: "GET"))
        return (res.serverManaged ?? false) ? res.balance : nil
    }

    /// One-time adoption of the legacy local balance. Idempotent server-side.
    static func migrate(claimedBalance: Int) async throws -> Int {
        let res: GrantResponse = try await send(request(
            path: "/credits/migrate", method: "POST", body: ["claimedBalance": claimedBalance]))
        return res.balance
    }

    /// Verifies a StoreKit transaction JWS server-side and grants the pack.
    /// Safe to retry — the server dedupes on transactionId.
    static func redeem(jws: String) async throws -> Int {
        let res: GrantResponse = try await send(request(
            path: "/credits/redeem", method: "POST", body: ["jws": jws]))
        return res.balance
    }

    // MARK: - Plumbing

    private static func request(path: String, method: String, body: [String: Any]? = nil) throws -> URLRequest {
        ReplyService.bootstrapAuthIfNeeded()
        guard let token = ReplyService.authToken else { throw CreditsError.notSignedIn }
        var req = URLRequest(url: URL(string: Constants.backendURL + path)!)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    private static func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw CreditsError.server(-1) }
        guard http.statusCode == 200 else { throw CreditsError.server(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
