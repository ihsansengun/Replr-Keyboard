import SwiftUI

enum TabSelection: Hashable { case replies, memory, settings }

struct CustomTabBar: View {
    @Binding var selection: TabSelection

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.replies,  icon: "clock",      label: "Replies")
            tabButton(.memory,   icon: "brain",       label: "Memory")
            tabButton(.settings, icon: "gearshape",   label: "Settings")
        }
        .frame(height: 56)
        .background(ReplrTheme.Color.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            ReplrTheme.Color.glassBorder.frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: TabSelection, icon: String, label: String) -> some View {
        let active = selection == tab
        Button { selection = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(ReplrTheme.Font.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(active ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .fill(active ? ReplrTheme.Color.accent.opacity(0.12) : .clear)
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
        .animation(ReplrTheme.Motion.quick, value: active)
    }
}
