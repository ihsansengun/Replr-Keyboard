import SwiftUI

// Measures the outer VStack's actual rendered height for keyboard sizing
private struct TotalHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct RepliesPanelView: View {
    @ObservedObject var model: KeyboardModel
    let replies: [String]

    @State private var selectedIndex: Int = 0
    @State private var totalH: CGFloat = 0

    private let maxKbH: CGFloat = 560  // upper bound for GeometryReader fallback

    private var currentReply: String {
        replies.indices.contains(selectedIndex) ? replies[selectedIndex] : replies.first ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model)

            if let name = model.contactName { contactHeader(name) }

            if let memoryName = model.memoryContactName {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles").font(.system(size: 9))
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

            // fixedSize forces the ScrollView to take its content's natural height —
            // no frame estimation needed, no gap, scroll kicks in when content overflows.
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(replies.enumerated()), id: \.offset) { idx, reply in
                        replyCard(idx: idx, reply: reply)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .fixedSize(horizontal: false, vertical: true)

            actionRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        // Measure the outer VStack's rendered height — reliable because every child has
        // a definite height (ScrollView is content-sized via fixedSize above).
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TotalHeightKey.self, value: geo.size.height)
            }
        )
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .onPreferenceChange(TotalHeightKey.self) { measured in
            guard measured > 10, abs(measured - totalH) > 1 else { return }
            totalH = measured
            reportHeight()
        }
        .onChange(of: model.contactName)       { _ in reportHeight() }
        .onChange(of: model.memoryContactName) { _ in reportHeight() }
        .onAppear { reportHeight() }
        .overlay {
            if model.showConsentPrompt {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
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
                            .fill(ReplrTheme.Color.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func reportHeight() {
        guard totalH > 10 else { return }
        model.onContentHeightChanged?(min(maxKbH, max(260, totalH)))
    }

    // MARK: - Reply card

    private func replyCard(idx: Int, reply: String) -> some View {
        Button { selectedIndex = idx } label: {
            HStack(alignment: .top, spacing: 10) {
                Text("\(idx + 1)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(
                        selectedIndex == idx ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary
                    )
                    .frame(width: 18)
                Text(reply)
                    .font(.system(size: 14))
                    .foregroundStyle(
                        selectedIndex == idx ? ReplrTheme.Color.accent : ReplrTheme.Color.textPrimary
                    )
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .fill(selectedIndex == idx ? ReplrTheme.Color.accentSubtle : ReplrTheme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .stroke(
                        selectedIndex == idx
                            ? ReplrTheme.Color.accent.opacity(0.60)
                            : ReplrTheme.Color.glassBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: selectedIndex == idx ? ReplrTheme.Color.accent.opacity(0.18) : .black.opacity(0.10),
                radius: selectedIndex == idx ? 6 : 2,
                x: 0, y: selectedIndex == idx ? 3 : 1
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: selectedIndex)
    }

    // MARK: - Contact header

    private func contactHeader(_ name: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "person.fill").font(.system(size: 9))
                Text(name.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Button { model.startRenameContact() } label: {
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
            HStack(spacing: 8) {
                Text(sentReply)
                    .font(.system(size: 12))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: { model.onUndoInsert?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .semibold))
                        Text("Undo").font(.system(size: 12, weight: .medium))
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
            HStack(spacing: 8) {
                Button(action: { model.selectReply(currentReply) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                        Text("Insert reply")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .padding(.horizontal, 16)
                    .foregroundColor(ReplrTheme.Color.onAccent)
                    .background(Capsule().fill(ReplrTheme.Color.accent))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1).blendMode(.overlay)
                    )
                    .shadow(color: ReplrTheme.Color.accentGlow, radius: 14, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert reply")

                Button { model.regenerateReplies() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Regenerate")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Regenerate replies")

                Button { model.regenerate() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 42, height: 40)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset")
            }
        }
    }
}
