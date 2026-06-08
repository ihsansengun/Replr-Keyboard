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
            ReplyService.authToken = token
        } else {
            isSignedIn = false
        }
        userEmail  = Keychain.load(forKey: Keys.userEmail)
        super.init()
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

        ReplyService.authToken = decoded.token
        isSignedIn = true
        userEmail  = email ?? Keychain.load(forKey: Keys.userEmail)
    }

    // MARK: - Sign Out

    func signOut() {
        Keychain.delete(forKey: Keys.sessionToken)
        Keychain.delete(forKey: Keys.userEmail)
        Keychain.delete(forKey: Keys.userName)
        ReplyService.authToken = nil
        isSignedIn = false
        userEmail  = nil
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case invalidIdentityToken
        case serverError

        var errorDescription: String? {
            switch self {
            case .invalidIdentityToken: return "Apple sign-in failed. Please try again."
            case .serverError:          return "Couldn't connect to Replr. Check your connection and try again."
            }
        }
    }
}
