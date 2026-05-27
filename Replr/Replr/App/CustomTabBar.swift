import SwiftUI

enum TabSelection: Hashable { case replies, memory, settings }

struct CustomTabBar: View {
    @Binding var selection: TabSelection

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.replies,  icon: "clock",     activeIcon: "clock.fill",      label: "Replies")
            tabButton(.memory,   icon: "brain",     activeIcon: "brain.fill",       label: "Memory")
            tabButton(.settings, icon: "gearshape", activeIcon: "gearshape.fill",   label: "Settings")
        }
        .padding(5)
        .background(
            Capsule()
                .fill(ReplrTheme.Color.surface.opacity(0.92))
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 6)
        .shadow(color: ReplrTheme.Color.accentGlow.opacity(0.50), radius: 24, x: 0, y: 0)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func tabButton(_ tab: TabSelection, icon: String, activeIcon: String, label: String) -> some View {
        let active = selection == tab
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selection = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: active ? activeIcon : icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(active ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(active ? ReplrTheme.Color.accent.opacity(0.12) : .clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        active ? ReplrTheme.Color.accent.opacity(0.30) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.30, dampingFraction: 0.85), value: active)
    }
}
