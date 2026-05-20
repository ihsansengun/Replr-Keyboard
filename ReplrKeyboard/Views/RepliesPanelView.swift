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
            // Mode segmented control only — tone moves to bottom
            ModeSegmentedControl(model: model)
                .padding(.bottom, 4)
                .background(KBColors.deep)
                .overlay(alignment: .bottom) { KBColors.borderHair.frame(height: 0.5) }

            // Contact header: name + rename + N of M
            if let name = model.contactName {
                contactHeader(name)
                KBColors.borderHair.frame(height: 0.5)
            }

            // Reply carousel
            ReplyCarouselView(
                replies: replies,
                lastInsertedReply: model.lastInsertedReply,
                currentPage: $currentPage
            )

            // Page dots
            pageDots
                .padding(.vertical, 6)

            KBColors.borderHair.frame(height: 0.5)

            // Action row: wide Insert primary + Edit secondary (or undo when sent)
            actionRow
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            KBColors.borderHair.frame(height: 0.5)

            // Tone strip at bottom + regenerate button
            toneRow
        }
        .background(KBColors.background)
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
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(KBColors.textPrimary)
            .padding(.leading, 14)

            Spacer()

            if replies.count > 1 {
                Text("\(currentPage + 1) of \(replies.count)")
                    .font(.system(size: 11))
                    .foregroundColor(KBColors.textDim)
                    .padding(.trailing, 14)
            }
        }
        .frame(height: 28)
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<replies.count, id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? KBColors.accent : KBColors.textDim.opacity(0.35))
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
                    .foregroundColor(KBColors.textDim)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { model.onUndoInsert?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Undo")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(KBColors.accent)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(KBColors.undoBtnBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(KBColors.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .animation(.easeInOut(duration: 0.2), value: model.lastInsertedReply)
        } else {
            // Normal state: Insert primary + Edit secondary
            HStack(spacing: 8) {
                Button(action: { model.selectReply(currentReply) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Insert reply")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(KBColors.accentFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(KBColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert reply")

                Button("Edit") { model.editReply(currentReply) }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KBColors.textPrimary)
                    .frame(width: 56, height: 42)
                    .background(KBColors.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(KBColors.borderHair, lineWidth: 0.5)
                    )
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tone row at bottom + regenerate

    private var toneRow: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(
                        model.tones.filter { model.inputMode == .chat || $0.name != "Dating" }
                    ) { tone in
                        TonePill(
                            name: tone.name,
                            isSelected: tone.name == model.selectedTone.name,
                            action: {
                                model.selectTone(tone)
                                if model.inputMode == .email {
                                    model.generateEmailReply()
                                } else {
                                    model.regenerate()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            KBColors.borderDim.frame(width: 0.5, height: 16)

            Button { model.regenerate() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13))
                    .foregroundColor(KBColors.textDim)
                    .frame(width: 40, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New replies")

            if model.needsGlobeKey {
                KBColors.borderDim.frame(width: 0.5, height: 16)
                Button { model.onSwitchKeyboard?() } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 36, height: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 38)
        .overlay(alignment: .top) { KBColors.borderHair.frame(height: 0.5) }
    }
}
