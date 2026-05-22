import SwiftUI

struct ErrorPanelView: View {
    let message: String
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model)
            errorContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
    }

    private var errorContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(ReplrTheme.Color.accent.opacity(0.85))
                .padding(.bottom, 8)

            Text("Couldn't generate replies")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ReplrTheme.Color.textPrimary)

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(ReplrTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
                .padding(.top, 4)

            Spacer(minLength: 0)

            Button { model.retryGeneration() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                    Text("Try again")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(ReplrTheme.Color.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(ReplrTheme.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}
