import SwiftUI

// MARK: - Unified reply carousel (chat + email)

struct ReplyCarouselView: View {
    let replies: [String]
    let lastInsertedReply: String?
    @Binding var currentPage: Int

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                ForEach(Array(replies.enumerated()), id: \.offset) { idx, reply in
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(reply)
                            .font(ReplrTheme.Font.callout)
                            .foregroundColor(
                                reply == lastInsertedReply
                                    ? ReplrTheme.Color.textSecondary
                                    : ReplrTheme.Color.textPrimary
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .frame(width: w)
                }
            }
            .offset(x: -CGFloat(currentPage) * w + dragOffset)
            .animation(dragOffset == 0 ? .easeInOut(duration: 0.2) : nil, value: currentPage)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .updating($dragOffset) { val, state, _ in
                        guard abs(val.translation.width) > abs(val.translation.height) else { return }
                        let cap = w * 0.5
                        state = max(-cap, min(cap, val.translation.width))
                    }
                    .onEnded { val in
                        guard abs(val.translation.width) > abs(val.translation.height) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if val.translation.width < -(w * 0.2) {
                                currentPage = min(currentPage + 1, replies.count - 1)
                            } else if val.translation.width > w * 0.2 {
                                currentPage = max(currentPage - 1, 0)
                            }
                        }
                    }
            )
        }
        .clipped()
    }
}
