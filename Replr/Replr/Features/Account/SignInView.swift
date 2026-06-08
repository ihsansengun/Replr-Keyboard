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

                // ── Brand mark ────────────────────────────────────────────────
                ZStack {
                    // Gradient aura behind the icon — makes the brand gradient prominent
                    ReplrTheme.Color.brandGradient
                        .blur(radius: 52)
                        .frame(width: 260, height: 260)
                        .opacity(colorScheme == .dark ? 0.38 : 0.22)

                    // App icon (gradient bg + white bird, baked in); shown with iOS-standard
                    // squircle radius (~22pt for 112pt side).
                    Image("ReplrLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.15),
                                radius: 16, y: 6)
                }

                Spacer().frame(height: ReplrTheme.Spacing.xl)

                // ── Wordmark ──────────────────────────────────────────────────
                VStack(spacing: ReplrTheme.Spacing.xs) {
                    Text("Replr")
                        .font(ReplrTheme.Font.serif(36, weight: .bold))
                        .foregroundStyle(ReplrTheme.Color.textPrimary)

                    Text("AI-powered replies, instantly.")
                        .font(ReplrTheme.Font.callout)
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                Spacer()

                // ── Sign-in controls ──────────────────────────────────────────
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
                    .clipShape(Capsule())
                    .padding(.horizontal, ReplrTheme.Spacing.screenMarginApp)

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
            let appleCode = (err as? ASAuthorizationError)?.code.rawValue
            errorMessage = appleCode != nil
                ? "Sign in failed (code \(appleCode!)). Check Settings → Apple ID → Password & Security → Apps Using Apple ID."
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
