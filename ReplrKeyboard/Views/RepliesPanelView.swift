import SwiftUI

// Sums the natural heights of the panel's three pieces (header + cards + action row). Each piece
// reports its OWN height via .background(heightReporter), so the total is the true CONTENT height,
// independent of the keyboard frame. The cards section lives inside a ScrollView: the GeometryReader
// is placed on the inner VStack (not the ScrollView itself), so it still measures the full natural
// cards height, not the clipped viewport height. This lets the keyboard grow to fit short replies
// while also adapting gracefully when the system gives us less space than requested (e.g. Instagram
// constrains the keyboard area) — the ScrollView scrolls rather than overflowing/clipping.
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value += nextValue() }
}

struct RepliesPanelView: View {
    @ObservedObject var model: KeyboardModel
    let replies: [String]

    @State private var selectedIndex: Int = 0

    private var currentReply: String {
        replies.indices.contains(selectedIndex) ? replies[selectedIndex] : replies.first ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top chrome — pinned, always visible.
            // isModeHidden: the Chat/Email mode is already fixed once replies are showing;
            // hiding it reclaims ~44 px — critical on apps that constrain keyboard height
            // (e.g. WhatsApp gives ~200 px, so every pixel of overhead costs card space).
            VStack(spacing: 0) {
                KeyboardHeader(model: model, isModeHidden: true)

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
            }
            .background(heightReporter)

            // Reply cards — in a ScrollView so the section fills whatever vertical space remains
            // between the header and action row. The inner VStack still measures its NATURAL height
            // via heightReporter, which drives the keyboard height (keyboard grows to fit short
            // replies). When the system allocates less than we asked for (e.g. Instagram has an
            // input-accessory bar that eats into the keyboard area), the ScrollView adapts instead
            // of overflowing — no top/bottom clipping.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(replies.enumerated()), id: \.offset) { idx, reply in
                        replyCard(idx: idx, reply: reply)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(heightReporter)
            }

            actionRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(heightReporter)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        // Sum of the three pieces' natural heights = the panel's true content height. Drives the
        // keyboard height (clamped in the controller). Re-fires whenever the text wraps or the
        // replies change, so the keyboard always fits exactly — no clip, no gap.
        .onPreferenceChange(ContentHeightKey.self) { measured in
            guard measured > 10 else { return }
            model.onContentHeightChanged?(measured)
        }
        .overlay {
            if model.showConsentPrompt {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 14) {
                        Text("Before your first reply")
                            .font(ReplrTheme.Font.serif(17, weight: .bold))
                            .foregroundStyle(ReplrTheme.Color.textPrimary)
                        Text("Replr sent this screenshot to its server to generate these replies. The screenshot is not stored. Only a one-line summary stays on your device for the memory feature.")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
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

    /// A transparent measurer that contributes its backed view's natural height to ContentHeightKey.
    private var heightReporter: some View {
        GeometryReader { geo in
            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
        }
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
                    .background(Capsule().fill(ReplrTheme.Color.brandGradient))
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
                    .background(Capsule().fill(ReplrTheme.Color.textPrimary.opacity(0.06)))
                    .overlay(Capsule().strokeBorder(ReplrTheme.Color.textPrimary.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Regenerate replies")

                Button { model.regenerate() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 42, height: 40)
                        .background(Capsule().fill(ReplrTheme.Color.textPrimary.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(ReplrTheme.Color.textPrimary.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset")
            }
        }
    }
}
