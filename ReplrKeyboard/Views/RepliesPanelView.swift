import SwiftUI

struct RepliesPanelView: View {
    @ObservedObject var model: KeyboardModel
    let replies: [String]

    @State private var currentPage: Int = 0

    private var currentReply: String {
        replies.indices.contains(currentPage) ? replies[currentPage] : ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode segmented control + mark
            HStack(spacing: 0) {
                ModeSegmentedControl(model: model)
                Spacer()
                ReplrMark(size: 14)
                    .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(ReplrTheme.Color.bg)
            .overlay(alignment: .bottom) { ReplrTheme.Color.border.frame(height: 0.5) }

            // Contact header: name + rename + N of M
            if let name = model.contactName {
                contactHeader(name)
                ReplrTheme.Color.border.frame(height: 0.5)
            }

            // Memory cue
            if let memoryName = model.memoryContactName {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("Remembering your last chat with \(memoryName)")
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundStyle(ReplrTheme.Color.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReplrTheme.Color.accentSubtle)
                ReplrTheme.Color.border.frame(height: 0.5)
            }

            // Reply carousel
            ReplyCarouselView(
                replies: replies,
                lastInsertedReply: model.lastInsertedReply,
                currentPage: $currentPage
            )
            .frame(height: 88)

            // Page dots
            pageDots
                .padding(.vertical, 6)

            ReplrTheme.Color.border.frame(height: 0.5)

            // Action row: wide Insert primary + Edit secondary (or undo when sent)
            actionRow
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

        }
        .background(ReplrTheme.Color.bg)
    }

    // MARK: - Contact header

    private func contactHeader(_ name: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                Text(name.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Button {
                    model.startRenameContact()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(ReplrTheme.Color.textPrimary)
            .padding(.leading, 16)

            Spacer()

            if replies.count > 1 {
                Text("\(currentPage + 1) of \(replies.count)")
                    .font(.system(size: 11))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .padding(.trailing, 16)
            }
        }
        .frame(height: 28)
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<replies.count, id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary.opacity(0.35))
                    .frame(width: 5, height: 5)
                    .animation(.easeInOut(duration: 0.15), value: currentPage)
            }
        }
    }

    // MARK: - Action row

    @ViewBuilder
    private var actionRow: some View {
        if let sentReply = model.lastInsertedReply {
            // Sent state: undo button
            HStack(spacing: 8) {
                Text(sentReply)
                    .font(.system(size: 12))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { model.onUndoInsert?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Undo")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(ReplrTheme.Color.accent)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(ReplrTheme.Color.accentSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .stroke(ReplrTheme.Color.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .animation(.easeInOut(duration: 0.2), value: model.lastInsertedReply)
        } else {
            // Normal state: Insert primary + Edit + Reset
            HStack(spacing: 8) {
                Button(action: { model.selectReply(currentReply) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Insert reply")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(ReplrTheme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                            .overlay(ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert reply")

                Button("Edit") { model.editReply(currentReply) }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .frame(width: 56, height: 42)
                    .background(ReplrTheme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .stroke(ReplrTheme.Color.border, lineWidth: 0.5)
                    )
                    .buttonStyle(.plain)

                Button { model.regenerate() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                }
                .frame(width: 42, height: 42)
                .background(ReplrTheme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .stroke(ReplrTheme.Color.border, lineWidth: 0.5)
                )
                .buttonStyle(.plain)
                .accessibilityLabel("New replies")
            }
        }
    }

}
