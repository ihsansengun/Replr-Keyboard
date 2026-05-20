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
        .background(KBColors.background)
    }

    private var errorContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(KBColors.accent.opacity(0.8))

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 24)

            Button { model.retryGeneration() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Retry")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(KBColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(KBColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(KBColors.borderHair, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
