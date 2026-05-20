import SwiftUI

// MARK: - Unified reply carousel (chat + email)

struct ReplyCarouselView: View {
    let replies: [String]
    let lastInsertedReply: String?
    @Binding var currentPage: Int

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(replies.enumerated()), id: \.offset) { idx, reply in
                ScrollView(.vertical, showsIndicators: false) {
                    Text(reply)
                        .font(.system(size: 15))
                        .foregroundColor(
                            reply == lastInsertedReply
                                ? KBColors.textDim
                                : KBColors.textPrimary
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}
