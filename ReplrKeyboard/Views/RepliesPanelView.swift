import SwiftUI

struct RepliesPanelView: View {
    @ObservedObject var model: KeyboardModel
    let replies: [String]

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model)
            if let name = model.contactName {
                contactChipRow(name)
                KBColors.borderHair.frame(height: 0.5)
            }
            ReplyListView(
                replies: replies,
                lastInsertedReply: model.lastInsertedReply,
                onSend: { model.selectReply($0) },
                onEdit: { model.editReply($0) },
                onUndo: { model.onUndoInsert?() }
            )
        }
        .background(KBColors.background)
    }

    private func contactChipRow(_ name: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .foregroundColor(KBColors.accent)
            .padding(.leading, 14)

            Spacer()

            Button { model.regenerate() } label: {
                Text("↺ New replies")
                    .font(.system(size: 10))
                    .foregroundColor(KBColors.textDim)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .frame(height: 26)
    }
}
