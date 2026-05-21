import SwiftUI
import UIKit

// MARK: - Color helpers

extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - ReplrTheme

enum ReplrTheme {

    // MARK: Color

    enum Color {
        static let bg            = SwiftUI.Color(light: .init(hex: 0xF4F4F5), dark: .init(hex: 0x0B0B0C))
        static let surface       = SwiftUI.Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x161617))
        static let surfaceRaised = SwiftUI.Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x202022))
        static let surfaceSunken = SwiftUI.Color(light: .init(hex: 0xECECEE), dark: .init(hex: 0x0B0B0C))
        static let surfaceGlass  = SwiftUI.Color(light: SwiftUI.Color(hex: 0xFFFFFF, alpha: 0.72),
                                                  dark: SwiftUI.Color(hex: 0x202022, alpha: 0.72))

        static let border        = SwiftUI.Color(light: .init(hex: 0xE4E4E6), dark: .init(hex: 0x2A2A2C))
        static let borderStrong  = SwiftUI.Color(light: .init(hex: 0xD4D4D7), dark: .init(hex: 0x3A3A3D))

        static let highlight     = SwiftUI.Color(white: 1, opacity: 0.06)

        static let textPrimary   = SwiftUI.Color(light: .init(hex: 0x161618), dark: .init(hex: 0xF5F5F6))
        static let textSecondary = SwiftUI.Color(light: .init(hex: 0x5C5C61), dark: .init(hex: 0x9B9B9F))
        static let textTertiary  = SwiftUI.Color(light: .init(hex: 0x97979C), dark: .init(hex: 0x65656A))

        static let accent        = SwiftUI.Color(light: .init(hex: 0x161618), dark: .init(hex: 0xF5F5F6))
        static let accentPressed = SwiftUI.Color(light: .init(hex: 0x363639), dark: .init(hex: 0xD4D4D6))
        static let onAccent      = SwiftUI.Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x0B0B0C))
        static let accentSubtle  = SwiftUI.Color(light: SwiftUI.Color(hex: 0x000000, alpha: 0.05),
                                                  dark: SwiftUI.Color(hex: 0xFFFFFF, alpha: 0.08))

        static let danger        = SwiftUI.Color(light: .init(hex: 0xC4453F), dark: .init(hex: 0xE06A66))
        static let success       = SwiftUI.Color(light: .init(hex: 0x3F7A52), dark: .init(hex: 0x6FB389))
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
        static let sm:   CGFloat = 10
        static let md:   CGFloat = 15
        static let lg:   CGFloat = 18
        static let xl:   CGFloat = 26
        static let full: CGFloat = 999
    }

    // MARK: Motion

    enum Motion {
        static let quick      = Animation.easeOut(duration: 0.15)
        static let standard   = Animation.easeInOut(duration: 0.22)
        static let expressive = Animation.spring(response: 0.34, dampingFraction: 0.78)
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
                .overlay(alignment: .top) {
                    if scheme == .dark {
                        Rectangle()
                            .fill(ReplrTheme.Color.highlight)
                            .frame(height: 1)
                    }
                }
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
