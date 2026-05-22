import SwiftUI

// MARK: - PrimaryButton

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ReplrTheme.Font.headline)
            .foregroundColor(ReplrTheme.Color.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .fill(ReplrTheme.Color.accent.opacity(isEnabled ? 1 : 0.45))
            )
            .elevatedSurface(.primaryAction)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ReplrTheme.Motion.quick, value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .buttonStyle(PrimaryButtonStyle())
    }
}

// MARK: - SecondaryButton

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ReplrTheme.Font.headline)
            .foregroundColor(ReplrTheme.Color.textPrimary.opacity(isEnabled ? 1 : 0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .fill(ReplrTheme.Color.surfaceRaised.opacity(isEnabled ? 1 : 0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .strokeBorder(ReplrTheme.Color.borderStrong.opacity(isEnabled ? 1 : 0.45), lineWidth: 1)
                    )
            )
            .elevatedSurface(.level1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ReplrTheme.Motion.quick, value: configuration.isPressed)
    }
}

struct SecondaryButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .buttonStyle(SecondaryButtonStyle())
    }
}

// MARK: - TertiaryButton

struct TertiaryButton: View {
    let label: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ReplrTheme.Font.headline)
                .foregroundColor(ReplrTheme.Color.textPrimary.opacity(isEnabled ? 1 : 0.45))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - IconTile

struct IconTile: View {
    let systemName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.lg, style: .continuous)
                .fill(ReplrTheme.Color.surfaceRaised)
                .elevatedSurface(.level1)

            Image(systemName: systemName)
                .font(.system(size: 34, weight: .light))
                .foregroundColor(ReplrTheme.Color.textPrimary)
        }
        .frame(width: 72, height: 72)
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.lg, style: .continuous)
                    .fill(ReplrTheme.Color.surfaceRaised)
            )
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.lg, style: .continuous))
            .elevatedSurface(.level1)
    }
}

// MARK: - Chip

struct Chip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ReplrTheme.Font.footnote)
                .foregroundColor(isSelected ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? ReplrTheme.Color.accent : Color.clear)
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.clear : ReplrTheme.Color.border,
                                lineWidth: 1
                            )
                        )
                )
        }
        .buttonStyle(.plain)
        .frame(height: 34)
        .animation(ReplrTheme.Motion.expressive, value: isSelected)
    }
}

// MARK: - SegmentedControl

struct SegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selected: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isActive = selected == option
                Button {
                    withAnimation(ReplrTheme.Motion.quick) { selected = option }
                } label: {
                    Text(label(option))
                        .font(ReplrTheme.Font.caption)
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundColor(isActive ? ReplrTheme.Color.textPrimary : ReplrTheme.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                                .fill(isActive ? ReplrTheme.Color.surfaceRaised : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm + 3, style: .continuous)
                .fill(ReplrTheme.Color.surfaceSunken)
        )
    }
}

// MARK: - ScreenScaffold

struct ScreenScaffold<Center: View>: View {
    let top: AnyView?
    let center: () -> Center
    let bottom: AnyView?

    init(
        top: AnyView? = nil,
        @ViewBuilder center: @escaping () -> Center,
        bottom: AnyView? = nil
    ) {
        self.top = top
        self.center = center
        self.bottom = bottom
    }

    var body: some View {
        VStack(spacing: 0) {
            if let top {
                top.padding(.horizontal, ReplrTheme.Spacing.screenMarginApp)
            }
            Spacer(minLength: 0)
            center()
                .padding(.horizontal, ReplrTheme.Spacing.screenMarginApp)
            Spacer(minLength: 0)
            if let bottom {
                bottom.padding(.horizontal, ReplrTheme.Spacing.screenMarginApp)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
    }
}
