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
        .padding(.horizontal, 10)
        .frame(height: 60)
        .background(ReplrTheme.Color.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            ReplrTheme.Color.glassBorder.frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: TabSelection, icon: String, activeIcon: String, label: String) -> some View {
        let active = selection == tab
        Button { selection = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: active ? activeIcon : icon)
                    .font(.system(size: 22, weight: .semibold))
                    .scaleEffect(active ? 1.12 : 1.0)
                    .shadow(color: active ? ReplrTheme.Color.accent.opacity(0.55) : .clear,
                            radius: 8, x: 0, y: 2)
                Text(label)
                    .font(ReplrTheme.Font.caption)
                    .fontWeight(active ? .semibold : .medium)
            }
            .foregroundStyle(active ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .fill(active ? ReplrTheme.Color.accent.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
        .animation(ReplrTheme.Motion.quick, value: active)
    }
}
