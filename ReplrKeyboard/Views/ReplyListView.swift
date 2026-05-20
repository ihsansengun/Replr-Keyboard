import SwiftUI

struct ReplyListView: View {
    let replies: [String]
    let lastInsertedReply: String?
    let onSend: (String) -> Void
    let onEdit: (String) -> Void
    let onUndo: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                    ReplyRowView(
                        text: reply,
                        isSent: reply == lastInsertedReply,
                        isDimmed: lastInsertedReply != nil && reply != lastInsertedReply,
                        onSend: { onSend(reply) },
                        onEdit: { onEdit(reply) },
                        onUndo: onUndo
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }
}

struct ReplyRowView: View {
    let text: String
    let isSent: Bool
    let isDimmed: Bool
    let onSend: () -> Void
    let onEdit: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(isSent ? KBColors.textDim : KBColors.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !isSent {
                Button("Edit", action: onEdit)
                    .font(.system(size: 11))
                    .foregroundColor(KBColors.textDim)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(KBColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .buttonStyle(.plain)
            }

            if isSent {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(KBColors.accent)
                        .frame(width: 28, height: 28)
                        .background(KBColors.undoBtnBg)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(KBColors.accent, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo send")
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(KBColors.accentFg)
                        .frame(width: 28, height: 28)
                        .background(KBColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send reply")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSent ? KBColors.sentCard : KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSent ? KBColors.accent.opacity(0.18) : KBColors.borderHair,
                    lineWidth: isSent ? 1.0 : 0.5
                )
        )
        .opacity(isDimmed ? 0.35 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSent)
        .animation(.easeInOut(duration: 0.2), value: isDimmed)
    }
}
