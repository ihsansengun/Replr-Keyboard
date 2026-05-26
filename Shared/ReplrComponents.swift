import SwiftUI

// MARK: - ShimmerOverlay

struct ShimmerOverlay: View {
    let cornerRadius: CGFloat
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: .clear,                  location: 0),
                    .init(color: .white.opacity(0.18),    location: 0.4),
                    .init(color: .white.opacity(0.32),    location: 0.5),
                    .init(color: .white.opacity(0.18),    location: 0.6),
                    .init(color: .clear,                  location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 2)
            .offset(x: -2 * geo.size.width + phase * 3 * geo.size.width)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - PrimaryButton

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ReplrTheme.Font.headline)
            .foregroundColor(ReplrTheme.Color.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .fill(ReplrTheme.Color.accent.opacity(isEnabled ? 1 : 0.40))
                    .overlay(isEnabled ? ShimmerOverlay(cornerRadius: ReplrTheme.Radius.md) : nil)
            )
            .shadow(
                color: colorScheme == .dark
                    ? ReplrTheme.Color.accent.opacity(isEnabled ? 0.45 : 0)
                    : .black.opacity(isEnabled ? 0.12 : 0),
                radius: colorScheme == .dark ? 18 : 8,
                x: 0, y: colorScheme == .dark ? 6 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
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
                    .fill(Color.white.opacity(isEnabled ? 0.04 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
                    )
            )
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
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.lg, style: .continuous)
                    .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
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
                .foregroundColor(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? ReplrTheme.Color.accentSubtle : ReplrTheme.Color.surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected
                                ? ReplrTheme.Color.accent.opacity(0.55)
                                : ReplrTheme.Color.glassBorder,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? ReplrTheme.Color.accent.opacity(0.20)
                        : .black.opacity(0.08),
                    radius: isSelected ? 6 : 2, x: 0, y: isSelected ? 3 : 1
                )
        }
        .buttonStyle(.plain)
        .frame(height: 34)
        .animation(ReplrTheme.Motion.expressive, value: isSelected)
    }
}

// MARK: - Badge

struct Badge: View {
    let systemImage: String?
    let label: String

    init(_ label: String, systemImage: String? = nil) {
        self.label = label
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(ReplrTheme.Color.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ReplrTheme.Color.accentSubtle)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(ReplrTheme.Color.accent.opacity(0.30), lineWidth: 1))
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
                        .shadow(
                            color: .black.opacity(isActive ? 0.12 : 0),
                            radius: 3, x: 0, y: 1
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
        .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
    }
}

// MARK: - ReplrBirdShape

struct ReplrBirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Bird content bounds in 1024×1024 SVG space (paths 2, 3, 4 only — skip rounded-rect border)
        let minX: CGFloat = 250, minY: CGFloat = 343
        let svgW: CGFloat = 536, svgH: CGFloat = 334  // 786-250, 677-343
        let scale = min(rect.width / svgW, rect.height / svgH)
        let tx = rect.minX + (rect.width - svgW * scale) / 2 - minX * scale
        let ty = rect.minY + (rect.height - svgH * scale) / 2 - minY * scale
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale + tx, y: y * scale + ty) }

        var path = Path()

        // Path 2: main diagonal chevron
        path.move(to: p(604.695923, 460.297485))
        path.addCurve(to: p(664.825378, 518.707642), control1: p(624.882202, 479.958008), control2: p(644.749390, 499.441620))
        path.addCurve(to: p(666.047485, 527.989075), control1: p(668.085266, 521.835938), control2: p(668.464661, 524.082825))
        path.addCurve(to: p(583.795593, 661.621887), control1: p(638.524841, 572.468201), control2: p(611.185608, 617.060669))
        path.addCurve(to: p(582.722168, 663.307556), control1: p(583.446655, 662.189575), control2: p(583.019409, 662.715271))
        path.addCurve(to: p(575.268799, 664.323730), control1: p(580.722168, 667.292358), control2: p(578.621826, 667.773987))
        path.addCurve(to: p(552.118896, 641.528381), control1: p(567.723022, 656.559204), control2: p(559.850159, 649.112854))
        path.addCurve(to: p(357.661194, 450.737762), control1: p(487.295319, 577.935913), control2: p(422.450165, 514.365479))
        path.addCurve(to: p(256.551483, 351.087006), control1: p(323.899048, 417.580780), control2: p(290.228271, 384.330719))
        path.addCurve(to: p(250.528839, 343.717194), control1: p(254.497971, 349.059875), control2: p(252.062302, 347.257690))
        path.addCurve(to: p(261.386810, 343.089844), control1: p(254.559677, 343.474579), control2: p(257.973145, 343.091461))
        path.addCurve(to: p(479.349121, 343.028687), control1: p(334.040924, 343.054932), control2: p(406.695038, 343.073425))
        path.addCurve(to: p(487.859711, 346.205597), control1: p(482.671814, 343.026642), control2: p(485.340454, 343.738770))
        path.addCurve(to: p(604.695923, 460.297485), control1: p(526.668884, 384.207306), control2: p(565.568054, 422.117096))
        path.closeSubpath()

        // Path 3a: bird head/wing
        path.move(to: p(697.252747, 391.848938))
        path.addCurve(to: p(704.688354, 396.699677), control1: p(698.922729, 395.167877), control2: p(701.564636, 396.158752))
        path.addCurve(to: p(754.959106, 411.038544), control1: p(721.950745, 399.688904), control2: p(738.878479, 403.922974))
        path.addCurve(to: p(784.669189, 443.910156), control1: p(769.717224, 417.568848), control2: p(780.367249, 427.905609))
        path.addCurve(to: p(784.518555, 451.995605), control1: p(785.349731, 446.441772), control2: p(786.056885, 449.040466))
        path.addCurve(to: p(771.448792, 449.394867), control1: p(780.162781, 451.103516), control2: p(775.846619, 449.768585))
        path.addCurve(to: p(708.629089, 461.911163), control1: p(749.335571, 447.515717), control2: p(728.425171, 451.998077))
        path.addCurve(to: p(696.826660, 473.708130), control1: p(703.388794, 464.535278), control2: p(699.612610, 468.566956))
        path.addCurve(to: p(683.908875, 496.807892), control1: p(692.623840, 481.463989), control2: p(688.251404, 489.128387))
        path.addCurve(to: p(676.716553, 497.625305), control1: p(681.243347, 501.521576), control2: p(680.841309, 501.566284))
        path.addCurve(to: p(629.070618, 452.041321), control1: p(660.824402, 482.441284), control2: p(644.940063, 467.249054))
        path.addCurve(to: p(575.304138, 400.563019), control1: p(611.156067, 434.873779), control2: p(593.309326, 417.634888))
        path.addCurve(to: p(574.690918, 393.274536), control1: p(572.612610, 398.011017), control2: p(571.992126, 396.404236))
        path.addCurve(to: p(633.908691, 363.436981), control1: p(590.354736, 375.110138), control2: p(609.714966, 363.513702))
        path.addCurve(to: p(697.252747, 391.848938), control1: p(658.708435, 363.358337), control2: p(681.365723, 370.158447))

        // Path 3b: eye cutout (evenodd makes this a hole)
        path.move(to: p(669.935974, 402.532501))
        path.addCurve(to: p(644.731750, 398.542297), control1: p(662.297424, 396.434631), control2: p(653.438782, 397.704742))
        path.addCurve(to: p(643.136841, 402.661285), control1: p(642.435913, 398.763123), control2: p(642.026672, 400.544891))
        path.addCurve(to: p(661.906006, 411.716034), control1: p(645.858459, 407.849548), control2: p(656.149963, 412.867340))
        path.addCurve(to: p(669.935974, 402.532501), control1: p(667.239990, 410.649139), control2: p(670.157532, 407.675110))
        path.closeSubpath()

        // Path 4: bottom triangle
        path.move(to: p(433.210693, 565.798828))
        path.addCurve(to: p(543.927307, 676.757690), control1: p(470.020538, 602.690308), control2: p(506.581757, 639.330994))
        path.addCurve(to: p(345.032776, 676.757690), control1: p(477.008698, 676.757690), control2: p(411.022247, 676.757690))
        path.addCurve(to: p(347.202362, 671.810303), control1: p(344.485260, 674.402832), control2: p(346.185394, 673.219421))
        path.addCurve(to: p(423.553467, 566.134827), control1: p(372.633392, 636.571228), control2: p(398.096680, 601.355347))
        path.addCurve(to: p(433.210693, 565.798828), control1: p(427.731140, 560.354858), control2: p(427.729462, 560.353638))
        path.closeSubpath()

        return path
    }
}

// MARK: - ReplrMark

struct ReplrMark: View {
    var size: CGFloat = 14

    var body: some View {
        ReplrBirdShape()
            .fill(ReplrTheme.Color.accent, style: FillStyle(eoFill: true))
            .frame(width: size * 1.6, height: size)
    }
}
