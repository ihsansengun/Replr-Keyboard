import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var signInTask: Task<Void, Never>? = nil

    var onSuccess: () -> Void

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon + wordmark
                VStack(spacing: ReplrTheme.Spacing.lg) {
                    // Actual app icon in a rounded rect (matches home screen appearance)
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: ReplrTheme.Color.accentGlow, radius: 16, y: 6)

                    VStack(spacing: ReplrTheme.Spacing.sm) {
                        Text("Replr")
                            .font(ReplrTheme.Font.serif(36, weight: .bold))
                            .foregroundStyle(ReplrTheme.Color.textPrimary)

                        Text("AI-powered replies, instantly.")
                            .font(ReplrTheme.Font.callout)
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // Sign-in controls
                VStack(spacing: ReplrTheme.Spacing.md) {
                    if let error = errorMessage {
                        Text(error)
                            .font(ReplrTheme.Font.footnote)
                            .foregroundStyle(ReplrTheme.Color.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, ReplrTheme.Spacing.s3xl)
                    }

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleResult(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.lg, style: .continuous))
                    .padding(.horizontal, ReplrTheme.Spacing.xxl)

                    Text("Your email is only used to help with account support.\nWe never send marketing emails.")
                        .font(ReplrTheme.Font.caption)
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ReplrTheme.Spacing.s3xl)
                }
                .padding(.bottom, ReplrTheme.Spacing.s4xl + ReplrTheme.Spacing.lg)
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
        if case .failure(let err) = result {
            if (err as? ASAuthorizationError)?.code == .canceled { return }
            // Show the actual Apple error for easier debugging
            let appleCode = (err as? ASAuthorizationError)?.code.rawValue
            errorMessage = appleCode != nil
                ? "Sign in failed (code \(appleCode!)). Make sure Sign in with Apple is enabled for this app in Settings."
                : "Sign in failed. Please try again."
            return
        }

        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
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
