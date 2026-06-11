import SwiftUI
import UIKit


// MARK: - ReplrTheme

enum ReplrTheme {

    // MARK: Color

    enum Color {
        // Backgrounds — dark: warm plum-black; light: warm white
        private static let _bg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.082, green: 0.063, blue: 0.102, alpha: 1) // #15101A
                : UIColor(red: 1.000, green: 0.973, blue: 0.961, alpha: 1) // #FFF8F5 warm white
        }
        // Surface — dark: #211826 plum, light: pure white
        private static let _surface = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.129, green: 0.094, blue: 0.149, alpha: 1) // #211826
                : UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1) // #FFFFFF
        }
        static let bg              = SwiftUI.Color(_bg)
        static let surface         = SwiftUI.Color(_surface)
        static let surfaceRaised   = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.176, green: 0.125, blue: 0.196, alpha: 1) // #2D2032
                : UIColor.white
        })
        static let surfaceRaisedHi = SwiftUI.Color(UIColor.systemFill)
        static let surfaceSunken   = SwiftUI.Color(UIColor.secondarySystemFill)
        static let surfaceGlass    = SwiftUI.Color(_bg).opacity(0.72)

        // Borders / separators
        static let border          = SwiftUI.Color(UIColor.separator).opacity(0.5)
        static let borderStrong    = SwiftUI.Color(UIColor.separator)
        // Glass border: adaptive — subtle gray in light, subtle white in dark
        static let glassBorder     = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.10)
                : UIColor.black.withAlphaComponent(0.08)
        })

        // Text — iOS semantic labels
        static let textPrimary     = SwiftUI.Color.primary
        static let textSecondary   = SwiftUI.Color.secondary
        static let textTertiary    = SwiftUI.Color(UIColor.tertiaryLabel)

        // Accent — Flirt rose, hardcoded so the keyboard extension bundle gets it too
        private static let _accent = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 1.000, green: 0.435, blue: 0.569, alpha: 1) // #FF6F91 — flirt rose
                : UIColor(red: 0.910, green: 0.267, blue: 0.478, alpha: 1) // #E8447A — deeper rose for light contrast
        }
        static let accent          = SwiftUI.Color(_accent)
        static let accentPressed   = SwiftUI.Color(_accent)
        // onAccent: white — AA on #FF6F91 (dark) and #E8447A (light)
        static let onAccent        = SwiftUI.Color.white
        static let accentSubtle    = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? _accent.withAlphaComponent(0.12)
                : _accent.withAlphaComponent(0.18)
        })
        static let accentSoft      = SwiftUI.Color(_accent).opacity(0.12)
        // Glow — used as box-shadow color on primary actions and active states
        static let accentGlow = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 1.000, green: 0.435, blue: 0.569, alpha: 0.42)
                : UIColor(red: 0.910, green: 0.267, blue: 0.478, alpha: 0.22)
        })

        // Brand gradient — rose → coral → amber. Constant in both modes; the
        // signature surface for primary CTAs, active chips, and brand marks.
        // LinearGradient conforms to ShapeStyle + View, so use it directly in
        // .fill(...) / .background(...).
        static let brandGradient = LinearGradient(
            colors: [
                SwiftUI.Color(red: 1.000, green: 0.369, blue: 0.541), // #FF5E8A
                SwiftUI.Color(red: 1.000, green: 0.478, blue: 0.349), // #FF7A59
                SwiftUI.Color(red: 1.000, green: 0.706, blue: 0.369), // #FFB45E
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// The amber stop of the brand gradient (#FFB45E) as a standalone accent —
        /// used for onboarding one-word highlights and hand-drawn doodle coachmarks.
        static let amber = SwiftUI.Color(red: 1.000, green: 0.706, blue: 0.369)

        /// Live accent as resolved RGBA (0–1) for a scheme. Lets Lottie's
        /// ColorValueProvider read the current accent without importing Lottie here.
        static func accentRGBA(for scheme: ColorScheme) -> (r: Double, g: Double, b: Double, a: Double) {
            let ui = _accent.resolvedColor(
                with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b), Double(a))
        }

        // Semantic status colors — iOS adaptive
        static let danger          = SwiftUI.Color(UIColor.systemRed)
        static let success         = SwiftUI.Color(UIColor.systemGreen)
    }

    // MARK: Font

    enum Font {
        static let display  = SwiftUI.Font.system(size: 32, weight: .bold,     design: .default)
        static let title    = SwiftUI.Font.system(size: 26, weight: .bold,     design: .default)
        static let heading  = SwiftUI.Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold, design: .default)
        static let body     = SwiftUI.Font.system(size: 17, weight: .regular,  design: .default)
        static let callout  = SwiftUI.Font.system(size: 15, weight: .regular,  design: .default)
        static let footnote = SwiftUI.Font.system(size: 13, weight: .regular,  design: .default)
        static let caption  = SwiftUI.Font.system(size: 12, weight: .medium,   design: .default)
        static let overline = SwiftUI.Font.system(size: 12, weight: .semibold, design: .default)
        // Tracking must be applied as .tracking(value) at call site — Font constants cannot carry tracking.
        // display: -0.5, title: -0.4, heading: -0.2, overline: +1.5, rest: 0

        // MARK: Serif display — Fraunces (bundled). Onboarding / marketing headlines ONLY; see DESIGN.md.
        /// Fraunces serif at an explicit size/weight. Falls back to the system serif (New York)
        /// if the bundled font isn't registered (e.g. in the keyboard extension), so headlines never break.
        static func serif(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            let bold = (weight == .bold || weight == .heavy || weight == .black)
            let face = bold ? "Fraunces-Bold" : "Fraunces-SemiBold"
            if UIFont(name: face, size: size) != nil {
                return .custom(face, size: size)
            }
            return .system(size: size, weight: weight, design: .serif)
        }
        static var serifDisplay: SwiftUI.Font { serif(34, weight: .bold) }   // big claim headlines
        static var serifTitle:   SwiftUI.Font { serif(26, weight: .semibold) } // step titles
    }

    // MARK: Spacing

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 24
        static let s3xl: CGFloat = 32
        static let s4xl: CGFloat = 40
        static let s5xl: CGFloat = 56
        static let s6xl: CGFloat = 72

        // 8pt grid extras
        static let s48:  CGFloat = 48
        static let s64:  CGFloat = 64
        static let s96:  CGFloat = 96

        static let screenMarginApp:      CGFloat = 24
        static let screenMarginKeyboard: CGFloat = 16
        static let rowVertical:          CGFloat = 12
    }

    // MARK: Radius

    enum Radius {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        /// App cards (brandCard) — softer than `md`; the keyboard keeps its own radii.
        static let card: CGFloat = 18
        static let full: CGFloat = 999
    }

    // MARK: Motion

    enum Motion {
        static let quick      = Animation.easeOut(duration: 0.15)
        static let standard   = Animation.easeInOut(duration: 0.22)
        static let expressive = Animation.spring(response: 0.34, dampingFraction: 0.78)
        static let shimmer    = Animation.linear(duration: 1.4).repeatForever(autoreverses: false)
        static let pulse      = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
        static let coachmark  = Animation.easeOut(duration: 0.24)
    }

}

// MARK: - ElevatedSurface modifier

enum ElevationLevel { case level1, level2, primaryAction }

struct ElevatedSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let level: ElevationLevel

    func body(content: Content) -> some View {
        switch level {
        case .level1, .level2:
            content
                .shadow(
                    color: scheme == .dark
                        ? Color(white: 0, opacity: 0.55)
                        : Color(white: 0, opacity: 0.07),
                    radius: scheme == .dark ? 10 : 20,
                    x: 0,
                    y: scheme == .dark ? 6 : 4
                )
        case .primaryAction:
            content
                .shadow(
                    color: scheme == .dark
                        ? Color(white: 0, opacity: 0.60)
                        : Color(white: 0, opacity: 0.18),
                    radius: 12, x: 0,
                    y: scheme == .dark ? 8 : 10
                )
                .shadow(
                    color: scheme == .dark
                        ? Color(white: 1, opacity: 0.10)
                        : .clear,
                    radius: 12, x: 0, y: 0
                )
        }
    }
}

extension View {
    func elevatedSurface(_ level: ElevationLevel = .level1) -> some View {
        modifier(ElevatedSurface(level: level))
    }
}

// MARK: - BrandCard modifier

struct BrandCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(
                // Soft vertical sheen — raised at the top, settling into surface, so
                // cards read as lit objects instead of flat cutouts. In light mode
                // surfaceRaised == surface, so this collapses to a plain fill.
                LinearGradient(
                    stops: [
                        .init(color: ReplrTheme.Color.surfaceRaised, location: 0),
                        .init(color: ReplrTheme.Color.surface, location: 0.45),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.card, style: .continuous)
                    .strokeBorder(
                        scheme == .dark
                            ? ReplrTheme.Color.accent.opacity(0.10)
                            : ReplrTheme.Color.accent.opacity(0.28),
                        lineWidth: 1
                    )
            )
            .overlay(
                // Kit signature: hairline top-light, fading out by a third of the card.
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(scheme == .dark ? 0.14 : 0), location: 0),
                                .init(color: .white.opacity(0), location: 0.35),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: scheme == .dark
                    ? Color(white: 0, opacity: 0.55)
                    : ReplrTheme.Color.accent.opacity(0.10),
                radius: scheme == .dark ? 10 : 20,
                x: 0,
                y: scheme == .dark ? 6 : 2
            )
    }
}

// MARK: - Brand screen background (app tab roots)

/// Screen background with a faint rose radial wash behind the header area —
/// warms the dead ceiling above the first card. The opaque nav bar crops the
/// brightest zone, so what shows is a soft falloff under the title.
struct BrandScreenBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(alignment: .top) {
                RadialGradient(
                    colors: [
                        ReplrTheme.Color.accent.opacity(scheme == .dark ? 0.16 : 0.10),
                        .clear,
                    ],
                    center: .top, startRadius: 0, endRadius: 300
                )
                .frame(height: 280)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
    }
}

extension View {
    func brandCard() -> some View {
        modifier(BrandCard())
    }

    func brandScreenBackground() -> some View {
        modifier(BrandScreenBackground())
    }
}
