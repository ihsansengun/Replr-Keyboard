# Replr Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all hard-coded amber colors and scattered style values with a single monochrome design system (ReplrTheme + ReplrComponents) shared across both the companion app and keyboard extension targets.

**Architecture:** Two new files in `Shared/` — `ReplrTheme.swift` (all token values) and `ReplrComponents.swift` (reusable SwiftUI components) — registered in the Xcode pbxproj for both the `Replr` and `ReplrKeyboard` targets. Every screen is then rebuilt to reference only tokens and components, deleting all inline color/font/shadow definitions.

**Tech Stack:** SwiftUI, UIColor bridging for adaptive colors, SF Symbols, Xcode pbxproj manual editing

---

## Xcode Project Reference

- **Shared group UUID:** `57CF47CF2FB38B860034657F`
- **Replr Sources phase UUID:** `57CF47732FB384F10034657F`
- **ReplrKeyboard Sources phase UUID:** `57CF47D42FB38DD70034657F`
- **Planned UUIDs for ReplrTheme.swift:**
  - File ref: `AA00001100AA0000001100AA`
  - Replr build file: `AA00001100AA0000001100BB`
  - Keyboard build file: `AA00001100AA0000001100CC`
- **Planned UUIDs for ReplrComponents.swift:**
  - File ref: `AA00002200AA0000002200AA`
  - Replr build file: `AA00002200AA0000002200BB`
  - Keyboard build file: `AA00002200AA0000002200CC`

---

## Design System Token Reference

### Colors — Dark Mode
| Token | Value |
|---|---|
| bg | `#0B0B0C` |
| surface | `#161617` |
| surfaceRaised | `#202022` |
| border | `#2A2A2C` |
| borderStrong | `#3A3A3D` |
| highlight | `rgba(255,255,255,0.06)` |
| textPrimary | `#F5F5F6` |
| textSecondary | `#9B9B9F` |
| textTertiary | `#65656A` |
| accent | `#F5F5F6` |
| accentPressed | `#D4D4D6` |
| onAccent | `#0B0B0C` |
| accentSubtle | `rgba(255,255,255,0.08)` |
| danger | `#E06A66` |
| success | `#6FB389` |

### Colors — Light Mode
| Token | Value |
|---|---|
| bg | `#F4F4F5` |
| surface | `#FFFFFF` |
| surfaceSunken | `#ECECEE` |
| border | `#E4E4E6` |
| borderStrong | `#D4D4D7` |
| textPrimary | `#161618` |
| textSecondary | `#5C5C61` |
| textTertiary | `#97979C` |
| accent | `#161618` |
| accentPressed | `#363639` |
| onAccent | `#FFFFFF` |
| accentSubtle | `rgba(0,0,0,0.05)` |
| danger | `#C4453F` |
| success | `#3F7A52` |

### Typography
| Role | Size | Weight | Tracking |
|---|---|---|---|
| display | 32 | Bold | -0.5 |
| title | 26 | Bold | -0.4 |
| heading | 20 | Semibold | -0.2 |
| headline | 17 | Semibold | 0 |
| body | 17 | Regular | 0 |
| callout | 15 | Regular | 0 |
| footnote | 13 | Regular | 0 |
| caption | 12 | Medium | 0 |
| overline | 12 | Semibold | +1.5 |

### Spacing (4pt grid)
`4, 8, 12, 16, 20, 24, 32, 40, 56, 72`

### Radius
```
sm   = 10  (chips, segmented thumb)
md   = 15  (buttons, inputs)
lg   = 18  (cards, icon tiles)
xl   = 26  (sheets, hero containers)
full = 999 (avatars, pills)
```

---

## Task 0: Create ReplrTheme.swift and register in Xcode

**Files:**
- Create: `Shared/ReplrTheme.swift`
- Modify: `Replr/Replr.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create Shared/ReplrTheme.swift**

Create the file at `/Users/WORK2/Desktop/DesktopCloud/Replr/Shared/ReplrTheme.swift` with this exact content:

```swift
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
        static let s32: CGFloat = 32
        static let s40: CGFloat = 40
        static let s56: CGFloat = 56
        static let s72: CGFloat = 72

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

    // MARK: Elevation (shadow definitions)

    enum Elevation {
        struct Level {
            let shadows: [Shadow]
            let topHighlight: Bool
        }
        struct Shadow {
            let color: SwiftUI.Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        static let level1Light = Level(
            shadows: [
                Shadow(color: .init(white: 0, opacity: 0.06), radius: 2, x: 0, y: 1),
                Shadow(color: .init(white: 0, opacity: 0.06), radius: 10, x: 0, y: 6),
            ],
            topHighlight: false
        )
        static let level1Dark = Level(
            shadows: [
                Shadow(color: .init(white: 0, opacity: 0.55), radius: 10, x: 0, y: 6),
            ],
            topHighlight: true
        )
        static let primaryActionLight = Level(
            shadows: [
                Shadow(color: .init(white: 0, opacity: 0.18), radius: 13, x: 0, y: 10),
            ],
            topHighlight: false
        )
        static let primaryActionDark = Level(
            shadows: [
                Shadow(color: .init(white: 0, opacity: 0.6),  radius: 12, x: 0, y: 8),
                Shadow(color: .init(white: 1, opacity: 0.10), radius: 12, x: 0, y: 0),
            ],
            topHighlight: false
        )
    }
}

// MARK: - ElevatedSurface modifier

enum ElevationLevel { case level1, level2, primaryAction }

struct ElevatedSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let level: ElevationLevel

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if needsHighlight {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(ReplrTheme.Color.highlight)
                        .frame(height: 1)
                }
            }
            .shadow(color: shadow1Color, radius: shadow1Radius, x: 0, y: shadow1Y)
            .shadow(color: shadow2Color, radius: shadow2Radius, x: 0, y: shadow2Y)
    }

    private var isDark: Bool { scheme == .dark }

    private var needsHighlight: Bool {
        isDark && (level == .level1 || level == .level2)
    }

    private var shadow1Color:  Color  { isDark ? darkS1c  : lightS1c  }
    private var shadow1Radius: CGFloat { isDark ? darkS1r  : lightS1r  }
    private var shadow1Y:      CGFloat { isDark ? darkS1y  : lightS1y  }
    private var shadow2Color:  Color  { isDark ? darkS2c  : lightS2c  }
    private var shadow2Radius: CGFloat { isDark ? darkS2r  : lightS2r  }
    private var shadow2Y:      CGFloat { isDark ? darkS2y  : lightS2y  }

    // light
    private var lightS1c: Color  { level == .primaryAction ? Color(white: 0, opacity: 0.18) : Color(white: 0, opacity: 0.06) }
    private var lightS1r: CGFloat { level == .primaryAction ? 13 : 2 }
    private var lightS1y: CGFloat { level == .primaryAction ? 10 : 1 }
    private var lightS2c: Color  { level == .primaryAction ? .clear : Color(white: 0, opacity: 0.06) }
    private var lightS2r: CGFloat { 10 }
    private var lightS2y: CGFloat { 6 }

    // dark
    private var darkS1c: Color  { level == .primaryAction ? Color(white: 1, opacity: 0.10) : Color(white: 0, opacity: 0.55) }
    private var darkS1r: CGFloat { 12 }
    private var darkS1y: CGFloat { level == .primaryAction ? 0 : 6 }
    private var darkS2c: Color  { level == .primaryAction ? Color(white: 0, opacity: 0.60) : .clear }
    private var darkS2r: CGFloat { 12 }
    private var darkS2y: CGFloat { 8 }
}

extension View {
    func elevatedSurface(_ level: ElevationLevel = .level1) -> some View {
        modifier(ElevatedSurface(level: level))
    }
}
```

- [ ] **Step 2: Register ReplrTheme.swift in pbxproj**

Open `Replr/Replr.xcodeproj/project.pbxproj` and make three edits:

**Edit A** — Add file reference (inside the `/* Begin PBXFileReference section */` block, after any existing entry):
Find the line:
```
		57CF47CE2FB38B860034657F /* Constants.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Constants.swift; sourceTree = "<group>"; };
```
Add after it:
```
		AA00001100AA0000001100AA /* ReplrTheme.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReplrTheme.swift; sourceTree = "<group>"; };
```

**Edit B** — Add to Shared group children (UUID `57CF47CF2FB38B860034657F`):
Find:
```
			57CF47CD2FB38B860034657F /* AppGroupService.swift */,
```
Add after it:
```
				AA00001100AA0000001100AA /* ReplrTheme.swift */,
```

**Edit C** — Add build file entries. First, find the PBXBuildFile section and add:
Find:
```
		57CF47D02FB38B860034657F /* Constants.swift in Sources */ = {isa = PBXBuildFile; fileRef = 57CF47CE2FB38B860034657F /* Constants.swift */; };
		57CF47D12FB38B860034657F /* AppGroupService.swift in Sources */ = {isa = PBXBuildFile; fileRef = 57CF47CD2FB38B860034657F /* AppGroupService.swift */; };
```
Add after them:
```
		AA00001100AA0000001100BB /* ReplrTheme.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA00001100AA0000001100AA /* ReplrTheme.swift */; };
		AA00001100AA0000001100CC /* ReplrTheme.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA00001100AA0000001100AA /* ReplrTheme.swift */; };
```

**Edit D** — Add to Replr target's Sources phase (`57CF47732FB384F10034657F`):
Find:
```
				57CF47D02FB38B860034657F /* Constants.swift in Sources */,
```
Add after it:
```
				AA00001100AA0000001100BB /* ReplrTheme.swift in Sources */,
```

**Edit E** — Add to ReplrKeyboard target's Sources phase (`57CF47D42FB38DD70034657F`):
Find:
```
				57CF48072FB390BF0034657F /* Constants.swift in Sources */,
```
Add after it:
```
				AA00001100AA0000001100CC /* ReplrTheme.swift in Sources */,
```

- [ ] **Step 3: Build ReplrKeyboard scheme**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
xcodebuild -project Replr/Replr.xcodeproj -scheme ReplrKeyboard -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Build Replr scheme**

```bash
xcodebuild -project Replr/Replr.xcodeproj -scheme Replr -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Shared/ReplrTheme.swift Replr/Replr.xcodeproj/project.pbxproj
git commit -m "feat: add ReplrTheme token layer (monochrome design system)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 1: Create ReplrComponents.swift and register in Xcode

**Files:**
- Create: `Shared/ReplrComponents.swift`
- Modify: `Replr/Replr.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create Shared/ReplrComponents.swift**

Create the file at `/Users/WORK2/Desktop/DesktopCloud/Replr/Shared/ReplrComponents.swift`:

```swift
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ReplrTheme.Font.headline)
            .foregroundColor(ReplrTheme.Color.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .fill(ReplrTheme.Color.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .strokeBorder(ReplrTheme.Color.borderStrong, lineWidth: 1)
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

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ReplrTheme.Font.headline)
                .foregroundColor(ReplrTheme.Color.textPrimary)
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
                                .elevatedSurface(isActive ? .level1 : .level1)
                                .opacity(isActive ? 1 : 0)
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

// MARK: - ScreenScaffold (three-zone layout §8)

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
            if let top { top.padding(.horizontal, ReplrTheme.Spacing.screenMarginApp) }
            Spacer(minLength: 0)
            center()
                .padding(.horizontal, ReplrTheme.Spacing.screenMarginApp)
            Spacer(minLength: 0)
            if let bottom { bottom.padding(.horizontal, ReplrTheme.Spacing.screenMarginApp) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
    }
}
```

- [ ] **Step 2: Register ReplrComponents.swift in pbxproj**

Open `Replr/Replr.xcodeproj/project.pbxproj` and make the following edits:

**Edit A** — Add file reference after the ReplrTheme entry:
```
		AA00002200AA0000002200AA /* ReplrComponents.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReplrComponents.swift; sourceTree = "<group>"; };
```

**Edit B** — Add to Shared group children after ReplrTheme:
```
				AA00002200AA0000002200AA /* ReplrComponents.swift */,
```

**Edit C** — Add build file entries after the ReplrTheme build files:
```
		AA00002200AA0000002200BB /* ReplrComponents.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA00002200AA0000002200AA /* ReplrComponents.swift */; };
		AA00002200AA0000002200CC /* ReplrComponents.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA00002200AA0000002200AA /* ReplrComponents.swift */; };
```

**Edit D** — Add to Replr Sources phase after ReplrTheme:
```
				AA00002200AA0000002200BB /* ReplrComponents.swift in Sources */,
```

**Edit E** — Add to ReplrKeyboard Sources phase after ReplrTheme:
```
				AA00002200AA0000002200CC /* ReplrComponents.swift in Sources */,
```

- [ ] **Step 3: Build both schemes**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
xcodebuild -project Replr/Replr.xcodeproj -scheme ReplrKeyboard -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
xcodebuild -project Replr/Replr.xcodeproj -scheme Replr -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **` for both.

- [ ] **Step 4: Commit**

```bash
git add Shared/ReplrComponents.swift Replr/Replr.xcodeproj/project.pbxproj
git commit -m "feat: add ReplrComponents library (buttons, card, chip, segmented control, scaffold)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Rebuild OnboardingView.swift with design system

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Replace all `OBColors.*` references with `ReplrTheme.Color.*`, replace `GhostCTAButton`/`SolidCTAButton` with `PrimaryButton`/`TertiaryButton`, and adopt `ScreenScaffold` for all onboarding step screens. Remove the `OBColors` enum entirely.

Key mappings:
- `OBColors.bg` → `ReplrTheme.Color.bg`
- `OBColors.surface` → `ReplrTheme.Color.surface`
- `OBColors.accent` → `ReplrTheme.Color.accent`
- `OBColors.textPrimary` → `ReplrTheme.Color.textPrimary`
- `OBColors.textSecondary` → `ReplrTheme.Color.textSecondary`
- `OBColors.textTertiary` → `ReplrTheme.Color.textTertiary`
- `OBColors.border` → `ReplrTheme.Color.border`
- `SolidCTAButton` → `PrimaryButton` 
- `GhostCTAButton("Done →")` → `TertiaryButton`
- Delete the `OBColors` enum and `SolidCTAButton`/`GhostCTAButton` view definitions

Build after changes:
```bash
xcodebuild -project Replr/Replr.xcodeproj -scheme Replr -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Commit:
```bash
git add Replr/Replr/Features/Onboarding/OnboardingView.swift
git commit -m "feat: onboarding uses ReplrTheme — removes OBColors

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Rebuild keyboard panel views with design system

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift`
- Modify: `ReplrKeyboard/Views/LoadingPanelView.swift`
- Modify: `ReplrKeyboard/Views/RepliesPanelView.swift`
- Modify: `ReplrKeyboard/Views/ErrorPanelView.swift`
- Modify: `ReplrKeyboard/Views/DisambiguatePanelView.swift`
- Modify: `ReplrKeyboard/Views/ReplyListView.swift`

Replace all `KBColors.*` references with `ReplrTheme.Color.*`:
- `KBColors.background` → `ReplrTheme.Color.bg`
- `KBColors.surface` → `ReplrTheme.Color.surface`
- `KBColors.raised` → `ReplrTheme.Color.surfaceRaised`
- `KBColors.deep` → `ReplrTheme.Color.bg`
- `KBColors.accent` → `ReplrTheme.Color.accent`
- `KBColors.accentFg` → `ReplrTheme.Color.onAccent`
- `KBColors.accentBg` → `ReplrTheme.Color.accentSubtle`
- `KBColors.textPrimary` → `ReplrTheme.Color.textPrimary`
- `KBColors.textDim` → `ReplrTheme.Color.textSecondary`
- `KBColors.textGhost` → `ReplrTheme.Color.textTertiary`
- `KBColors.borderHair` → `ReplrTheme.Color.border`
- `KBColors.borderDim` → `ReplrTheme.Color.borderStrong`
- `KBColors.segmentedBg` → `ReplrTheme.Color.surfaceSunken`
- `KBColors.skeletonHighlight` → `ReplrTheme.Color.surfaceRaised`

Also:
- Replace `TonePill` with `Chip` component
- Replace `ModeSegmentedControl` with `SegmentedControl<KeyboardInputMode>` (add `Hashable` conformance to `KeyboardInputMode`)
- Delete `KBColors` struct, `TonePill`, `ModeSegmentedControl` definitions from KeyboardView.swift

Replace radius/font constants:
- `.clipShape(RoundedRectangle(cornerRadius: 12` → `ReplrTheme.Radius.md`
- `.clipShape(RoundedRectangle(cornerRadius: 10` → `ReplrTheme.Radius.sm`
- `.font(.system(size: 14, weight: .semibold))` → `.font(ReplrTheme.Font.callout)` (adjust as appropriate)
- `.font(.system(size: 11))` → `.font(ReplrTheme.Font.caption)`

Build after changes:
```bash
xcodebuild -project Replr/Replr.xcodeproj -scheme ReplrKeyboard -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Commit:
```bash
git add ReplrKeyboard/Views/
git commit -m "feat: keyboard views use ReplrTheme — removes KBColors

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Rebuild companion app views with design system

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift`
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`
- Modify: `Replr/Replr/Features/CaptureLog/CaptureLogView.swift` (or HistoryView.swift)
- Modify: `Replr/Replr/Features/Tones/TonesView.swift`
- Modify: `Replr/Replr/Features/Memory/ContactMemoryDetailView.swift`
- Modify: `Replr/Replr/Features/Memory/SummaryDetailView.swift` (or SummariesView.swift)

Replace all `Replr.*` color references with `ReplrTheme.Color.*`:
- `Replr.accent` → `ReplrTheme.Color.accent`
- `Replr.bg` → `ReplrTheme.Color.bg`
- `Replr.surface` → `ReplrTheme.Color.surface`
- `Replr.textPrimary` → `ReplrTheme.Color.textPrimary`
- etc.

In `ReplrApp.swift`:
- Remove `applyBrandAppearance()` amber UIAppearance calls
- Replace `.tint(Replr.accent)` with `.tint(ReplrTheme.Color.accent)`
- Remove `Replr` enum entirely
- Remove `.preferredColorScheme(.dark)` — app now adapts to system

Build after changes:
```bash
xcodebuild -project Replr/Replr.xcodeproj -scheme Replr -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Commit:
```bash
git add Replr/Replr/
git commit -m "feat: companion app uses ReplrTheme — removes Replr amber enum

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```
