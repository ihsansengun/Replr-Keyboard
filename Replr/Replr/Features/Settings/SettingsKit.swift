import SwiftUI

/// Uppercase section title + content rows on a brand card.
/// Shared by SettingsView and its sub-screens.
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .brandCard()
        }
    }
}

/// One settings row: horizontal content, standard padding and tap target.
struct SettingsRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
    }
}

/// Hairline divider between rows on a card.
struct CardDivider: View {
    var body: some View {
        ReplrTheme.Color.glassBorder
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}

/// Accent value + chevrons menu trigger (used by pickers in Memory settings).
struct SettingsMenuPicker<Items: View>: View {
    let label: String
    @ViewBuilder var items: () -> Items

    var body: some View {
        Menu { items() } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 15))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(ReplrTheme.Color.accent)
        }
        .buttonStyle(.plain)
    }
}

/// Trailing "state" text on a row (e.g. "Natural", "All set ✓", "84").
struct RowValue: View {
    let text: String
    var color: Color = ReplrTheme.Color.textSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(color)
    }
}

/// Trailing chevron for navigation rows.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ReplrTheme.Color.textTertiary)
    }
}
