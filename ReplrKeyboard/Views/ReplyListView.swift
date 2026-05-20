import SwiftUI

struct ReplyListView: View {
    let replies: [String]
    let onSend: (String) -> Void
    let onEdit: (String) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                    ReplyRowView(
                        text: reply,
                        onSend: { onSend(reply) },
                        onEdit: { onEdit(reply) }
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
    let onSend: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(KBColors.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Edit", action: onEdit)
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(KBColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .buttonStyle(.plain)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(KBColors.accentFg)
                    .frame(width: 28, height: 28)
                    .background(KBColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KBColors.borderHair, lineWidth: 0.5)
        )
    }
}
