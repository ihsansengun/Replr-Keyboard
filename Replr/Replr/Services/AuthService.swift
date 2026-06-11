import AuthenticationServices
import Combine
import Foundation
import Security

// MARK: - Keychain helper

enum Keychain {
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        var errorDescription: String? {
            switch self { case .saveFailed(let s): return "Keychain save failed: \(s)" }
        }
    }

    static func save(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      Bundle.main.bundleIdentifier ?? "com.ihsan.replr",
            kSecAttrAccount as String:      key,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:        data,
        ]
        SecItemDelete(query as CFDictionary)  // delete any previous value
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.ihsan.replr",
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.ihsan.replr",
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - AuthService

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var userEmail: String?

    private enum Keys {
        static let sessionToken = "replr.auth.sessionToken"
        static let userEmail    = "replr.auth.userEmail"
        static let userName     = "replr.auth.userName"
    }

    private override init() {
        // Keychain reads are synchronous and run on the main actor. At app scale
        // (< 3ms) this is acceptable; move off-main if init latency ever shows in profiling.
        if let token = Keychain.load(forKey: Keys.sessionToken) {
            isSignedIn = true
            ReplyService.setAuthToken(token)
        } else {
            isSignedIn = false
        }
        userEmail  = Keychain.load(forKey: Keys.userEmail)
        super.init()
        // Wire 401 responses back to sign-out
        ReplyService.onUnauthorized = { [weak self] in
            self?.signOut()
        }
    }

    var sessionToken: String? { Keychain.load(forKey: Keys.sessionToken) }
    var userName: String?     { Keychain.load(forKey: Keys.userName) }

    // MARK: - Sign In

    /// Called by SignInView after a successful ASAuthorizationAppleIDCredential.
    /// Sends the Apple identity token to the backend, stores the returned session token.
    func signIn(identityToken: Data, email: String?, name: String?) async throws {
        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidIdentityToken
        }

        let url = URL(string: Constants.backendURL + "/auth/apple")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        var bodyDict: [String: String] = ["identityToken": tokenString]
        if let email { bodyDict["email"] = email }
        if let name, !name.isEmpty { bodyDict["name"] = name }
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.serverError
        }
        guard http.statusCode == 200 else {
            throw http.statusCode == 401 ? AuthError.invalidIdentityToken : AuthError.serverError
        }

        struct AuthResponse: Decodable { let token: String }
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)

        try Keychain.save(decoded.token, forKey: Keys.sessionToken)
        if let email { try Keychain.save(email, forKey: Keys.userEmail) }
        if let name, !name.isEmpty { try Keychain.save(name, forKey: Keys.userName) }

        ReplyService.setAuthToken(decoded.token)
        isSignedIn = true
        userEmail  = email ?? Keychain.load(forKey: Keys.userEmail)

        // Adopt the local credit balance into this account's server ledger and
        // pull back the authoritative value. Safe to fire-and-forget — both are
        // retried on every app foreground.
        Task {
            await CreditsManager.shared.serverMigrateIfNeeded()
            await CreditsManager.shared.syncServerBalance()
        }
    }

    // MARK: - Delete Account

    /// App Review 5.1.1(v): permanently deletes the server account — user row,
    /// sessions, credit balance, and ledger — then clears local state exactly
    /// like sign-out. Remaining credits are forfeited; callers warn the user
    /// first. Signing in with Apple again later creates a fresh account.
    func deleteAccount() async throws {
        guard let token = sessionToken else {
            signOut()   // no server session — nothing remote to delete
            return
        }

        let url = URL(string: Constants.backendURL + "/auth/account")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.serverError }
        guard http.statusCode == 200 else {
            // The 30-day session can lapse before the user gets here. Deletion
            // needs a live session, so ask for a fresh sign-in instead of
            // pretending the account is gone.
            throw http.statusCode == 401 ? AuthError.sessionExpired : AuthError.serverError
        }

        // The server account (and its credit ledger) is gone — forfeit the local
        // mirror too, so the legacy offline path can't keep spending ghost credits.
        AppGroupService.shared.creditBalance = 0
        signOut()
    }

    // MARK: - Sign Out

    func signOut() {
        Keychain.delete(forKey: Keys.sessionToken)
        Keychain.delete(forKey: Keys.userEmail)
        Keychain.delete(forKey: Keys.userName)
        ReplyService.setAuthToken(nil)
        // A different Apple ID signing in later gets its own one-time server
        // credit migration.
        AppGroupService.shared.serverCreditsMigrated = false
        isSignedIn = false
        userEmail  = nil
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case invalidIdentityToken
        case serverError
        case sessionExpired

        var errorDescription: String? {
            switch self {
            case .invalidIdentityToken: return "Apple sign-in failed. Please try again."
            case .serverError:          return "Couldn't connect to Replr. Check your connection and try again."
            case .sessionExpired:       return "Your session has expired. Sign in again, then delete your account."
            }
        }
    }
}
