import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var signInTask: Task<Void, Never>? = nil

    /// Called by the parent (ReplrApp) when sign-in succeeds.
    var onSuccess: () -> Void

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: ReplrTheme.Spacing.lg) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(ReplrTheme.Color.brandGradient)

                    Text("Replr")
                        .font(ReplrTheme.Font.serif(38, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)

                    Text("AI reply suggestions — for any conversation.")
                        .font(ReplrTheme.Font.callout)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Sign in area
                VStack(spacing: ReplrTheme.Spacing.lg) {
                    if let error = errorMessage {
                        Text(error)
                            .font(ReplrTheme.Font.footnote)
                            .foregroundColor(ReplrTheme.Color.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleResult(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(10)
                    .padding(.horizontal, 24)

                    Text("Your email is used only for account support. We don't send marketing emails.")
                        .font(ReplrTheme.Font.caption)
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 52)
            }

            if isLoading {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
        .onDisappear {
            signInTask?.cancel()
        }
    }

    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result else {
            // .failure — ignore user-cancel (code 1001), show message for real errors
            if case .failure(let err) = result,
               (err as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Sign in failed. Please try again."
            }
            return
        }

        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken else {
            errorMessage = "Sign in failed. Please try again."
            return
        }

        let email = credential.email
        let name: String? = {
            guard let c = credential.fullName else { return nil }
            let parts = [c.givenName, c.familyName].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        isLoading = true
        errorMessage = nil

        signInTask = Task {
            do {
                try await authService.signIn(identityToken: identityToken, email: email, name: name)
                onSuccess()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
