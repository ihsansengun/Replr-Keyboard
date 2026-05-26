import SwiftUI
import UIKit


// MARK: - ReplrTheme

enum ReplrTheme {

    // MARK: Color

    enum Color {
        // Backgrounds — dark: Superwall deep navy; light: native gray
        private static let _bg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
                : .systemGray6
        }
        // Surface — dark: #131929, light: white card
        private static let _surface = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.075, green: 0.098, blue: 0.161, alpha: 1) // #131929
                : .systemBackground
        }
        static let bg              = SwiftUI.Color(_bg)
        static let surface         = SwiftUI.Color(_surface)
        static let surfaceRaised   = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.145, blue: 0.224, alpha: 1) // #1C2539
                : UIColor.tertiarySystemBackground
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
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.black.withAlphaComponent(0.07)
        })

        // Text — iOS semantic labels
        static let textPrimary     = SwiftUI.Color.primary
        static let textSecondary   = SwiftUI.Color.secondary
        static let textTertiary    = SwiftUI.Color(UIColor.tertiaryLabel)

        // Accent — Superwall Teal, hardcoded so keyboard extension bundle gets it too
        private static let _accent = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.710, blue: 0.643, alpha: 1) // #0DB5A4
                : UIColor(red: 0.000, green: 0.537, blue: 0.482, alpha: 1) // #00897B
        }
        static let accent          = SwiftUI.Color(_accent)
        static let accentPressed   = SwiftUI.Color(_accent)
        // onAccent: white — sufficient contrast on #0DB5A4 (dark) and #00897B (light)
        static let onAccent        = SwiftUI.Color.white
        static let accentSubtle    = SwiftUI.Color(_accent).opacity(0.12)
        static let accentSoft      = SwiftUI.Color(_accent).opacity(0.12)

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
                        : Color(white: 0, opacity: 0.06),
                    radius: scheme == .dark ? 10 : 2, x: 0,
                    y: scheme == .dark ? 6 : 1
                )
                .shadow(
                    color: scheme == .dark
                        ? .clear
                        : Color(white: 0, opacity: 0.06),
                    radius: 10, x: 0, y: 6
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
    func body(content: Content) -> some View {
        content
            .background(ReplrTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
            .elevatedSurface(.level1)
    }
}

extension View {
    func brandCard() -> some View {
        modifier(BrandCard())
    }
}
