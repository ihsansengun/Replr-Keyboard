import SwiftUI

struct RepliesPanelView: View {
    @ObservedObject var model: KeyboardModel
    let replies: [String]

    @State private var selectedIndex: Int = 0

    private var currentReply: String {
        replies.indices.contains(selectedIndex) ? replies[selectedIndex] : replies.first ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode segmented control + mark
            HStack(spacing: 0) {
                ModeSegmentedControl(model: model)
                Spacer()
                ReplrMark(size: 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ReplrTheme.Color.bg)

            ToneRow(model: model)

            // Contact header: name + rename + N of M
            if let name = model.contactName {
                contactHeader(name)
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
            }

            // Stacked reply list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(replies.enumerated()), id: \.offset) { idx, reply in
                        Button {
                            selectedIndex = idx
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(
                                        selectedIndex == idx
                                            ? ReplrTheme.Color.onAccent
                                            : ReplrTheme.Color.textTertiary
                                    )
                                    .frame(width: 18)
                                Text(reply)
                                    .font(.system(size: 14))
                                    .foregroundStyle(
                                        selectedIndex == idx
                                            ? ReplrTheme.Color.onAccent
                                            : ReplrTheme.Color.textPrimary
                                    )
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                                    .fill(
                                        selectedIndex == idx
                                            ? ReplrTheme.Color.accent
                                            : ReplrTheme.Color.surface
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                                    .stroke(
                                        selectedIndex == idx
                                            ? ReplrTheme.Color.accent.opacity(0.4)
                                            : ReplrTheme.Color.glassBorder,
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: selectedIndex == idx
                                    ? ReplrTheme.Color.accent.opacity(0.25)
                                    : .black.opacity(0.10),
                                radius: selectedIndex == idx ? 8 : 2,
                                x: 0, y: selectedIndex == idx ? 4 : 1
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.12), value: selectedIndex)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: 220)

            Spacer(minLength: 0)

            // Action row: wide Insert primary + Edit secondary (or undo when sent)
            actionRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

        }
        .background(ReplrTheme.Color.bg)
        .overlay {
            if model.showConsentPrompt {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                    VStack(spacing: 14) {
                        Text("Before your first reply")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Replr sent this screenshot to its server to generate these replies. The screenshot is not stored. Only a one-line summary stays on your device for the memory feature.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                        Button("Got it — show my replies") {
                            AppGroupService.shared.hasConsentedToCapture = true
                            model.showConsentPrompt = false
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(ReplrTheme.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.systemGray5))
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
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
                Text("\(selectedIndex + 1) of \(replies.count)")
                    .font(.system(size: 11))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .padding(.trailing, 16)
            }
        }
        .frame(height: 28)
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
                    .shadow(color: ReplrTheme.Color.accent.opacity(0.18), radius: 4, x: 0, y: 2)
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
                    .shadow(color: ReplrTheme.Color.accent.opacity(0.40), radius: 14, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert reply")

                Button("Edit") { model.editReply(currentReply) }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .frame(width: 56, height: 42)
                    .background(ReplrTheme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
                    .buttonStyle(.plain)

                Button { model.regenerate() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                }
                .frame(width: 42, height: 42)
                .background(ReplrTheme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
                .buttonStyle(.plain)
                .accessibilityLabel("New replies")
            }
        }
    }

}
