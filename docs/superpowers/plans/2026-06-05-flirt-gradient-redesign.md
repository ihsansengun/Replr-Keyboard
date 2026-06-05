# Flirt Gradient Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin Replr from the teal/navy identity to the warm "Flirt Gradient" language (rose → coral → amber) for the dating market, keeping full adaptive light **and** dark.

**Architecture:** Every color lives in `ReplrTheme.Color` as a dynamic `UIColor { tc in … }` provider (adaptive). The redesign is therefore almost entirely a **token swap** in one file, plus: a new `brandGradient` token, gradient fills on the primary CTAs, recoloring the accent inside the embedded Lottie JSON (a deterministic find/replace on the minified strings the app actually loads), two duplicated hardcoded backgrounds, and a rewrite of `DESIGN.md`.

**Tech Stack:** SwiftUI + UIKit dynamic colors, lottie-ios 4.6.0 (embedded raw-string JSON), Xcode 16. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-05-flirt-gradient-design.md`

---

## Palette reference (hex → normalized RGB)

The keyboard extension can't read asset catalogs, so all colors are written as `UIColor(red:green:blue:alpha:)` literals. Conversions used throughout this plan:

| Token | Mode | Hex | normalized `red, green, blue` |
|---|---|---|---|
| `bg` | dark | `#15101A` | `0.082, 0.063, 0.102` |
| `bg` | light | `#FFF8F5` | `1.000, 0.973, 0.961` |
| `surface` | dark | `#211826` | `0.129, 0.094, 0.149` |
| `surface` | light | `#FFFFFF` | `1.000, 1.000, 1.000` |
| `surfaceRaised` | dark | `#2D2032` | `0.176, 0.125, 0.196` |
| `surfaceRaised` | light | `#FFFFFF` | `UIColor.white` |
| `accent` | dark | `#FF6F91` | `1.000, 0.435, 0.569` |
| `accent` | light | `#E8447A` | `0.910, 0.267, 0.478` |
| gradient stop 1 | both | `#FF5E8A` | `1.000, 0.369, 0.541` |
| gradient stop 2 | both | `#FF7A59` | `1.000, 0.478, 0.349` |
| gradient stop 3 | both | `#FFB45E` | `1.000, 0.706, 0.369` |
| Lottie accent (base) | — | `#FF6F91` | `1, 0.435, 0.569` |
| Lottie accent (bright) | — | `#FF96AE` | `1, 0.588, 0.682` |

**Build command (the hard gate for every task):**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr/Replr && \
xcodebuild -project Replr.xcodeproj -scheme Replr -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
```

Expected: `** BUILD SUCCEEDED **`. (SourceKit "No such module Lottie / Cannot find ReplrTheme" diagnostics in the editor are FALSE POSITIVES — only the `xcodebuild` result is authoritative. `iPhone 16` does not exist on this machine; use `iPhone 17`.)

**Visual verification helper (light + dark) used in several tasks:**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator
xcrun simctl ui booted appearance dark  # then re-run with: light
xcrun simctl io booted screenshot /tmp/replr-check.png
```

---

## File map

| File | Responsibility | Change |
|---|---|---|
| `Shared/ReplrTheme.swift` | All design tokens (source of truth) | Swap 6 color blocks to warm; add `brandGradient` token |
| `Replr/Replr/App/ReplrApp.swift` | App root window bg (duplicates `bg`) | Swap bg RGB |
| `ReplrKeyboard/KeyboardViewController.swift` | Keyboard root bg (duplicates `bg`) | Swap bg RGB |
| `Shared/ReplrComponents.swift` | Shared button/chip styles | `PrimaryButton` + selected `Chip` → gradient |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Keyboard idle card | CTAs → gradient; recolor embedded Lottie accent (3 tokens) |
| `Replr/Replr/Features/Onboarding/OnboardingView.swift` | Onboarding + tutorial carousel | Recolor embedded Lottie accent (13 tokens) |
| `ReplrKeyboard/Resources/capture_steps.json` + `Replr/Replr/Features/Onboarding/{onboarding_steps.json, tutorial_lottie/tut_*.json}` | Canonical Lottie source assets (NOT loaded at runtime) | Recolor accent (hygiene) |
| `DESIGN.md` | AI-facing design spec | Rewrite to Flirt Gradient |

Everything else (`TonesView`, `SettingsView`, `CaptureLogView`, `Badge`, `BrandToggle`, `ReplrMark`, `SegmentedControl`, `brandCard`, etc.) references `ReplrTheme.*` and **re-skins automatically** once Task 1 lands — no per-view edits.

> **Note on Lottie tinting (decision):** The spec floated runtime tinting via `ColorValueProvider`. On inspection, the animations' accent fills are **color-identified, not name-identified** (all fills are named `"f"`; accent = the teal arrays, neutrals = white/gray), and the current animations already use a single non-adaptive accent. A deterministic **recolor of the teal arrays** is therefore simpler, fully verifiable, and equally swappable (change the target RGB + re-run), with none of the keypath-matching fragility. This plan uses recolor. To change the palette again later: edit the token in Task 1 and re-run the find/replace in Task 5.

---

### Task 1: Re-skin `ReplrTheme.Color` + add `brandGradient`

**Files:**
- Modify: `Shared/ReplrTheme.swift:12-71`

- [ ] **Step 1: Swap the background block**

Replace (lines 12-23):

```swift
        // Backgrounds — dark: deep navy; light: warm cream
        private static let _bg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
                : UIColor(red: 0.961, green: 0.945, blue: 0.922, alpha: 1) // #F5F1EB warm cream
        }
        // Surface — dark: #131929, light: near-white warm
        private static let _surface = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.075, green: 0.098, blue: 0.161, alpha: 1) // #131929
                : UIColor(red: 0.992, green: 0.988, blue: 0.980, alpha: 1) // #FDFCFA
        }
```

with:

```swift
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
```

- [ ] **Step 2: Swap `surfaceRaised`**

Replace (lines 26-30):

```swift
        static let surfaceRaised   = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.145, blue: 0.224, alpha: 1) // #1C2539
                : UIColor.white
        })
```

with:

```swift
        static let surfaceRaised   = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.176, green: 0.125, blue: 0.196, alpha: 1) // #2D2032
                : UIColor.white
        })
```

- [ ] **Step 3: Swap `glassBorder` opacities**

Replace (lines 39-43):

```swift
        static let glassBorder     = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.black.withAlphaComponent(0.12)
        })
```

with:

```swift
        static let glassBorder     = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.10)
                : UIColor.black.withAlphaComponent(0.08)
        })
```

- [ ] **Step 4: Swap the accent block + comment**

Replace (lines 50-59):

```swift
        // Accent — Superwall Teal, hardcoded so keyboard extension bundle gets it too
        private static let _accent = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.090, green: 0.918, blue: 0.851, alpha: 1) // #17EAD9 — brand kit teal
                : UIColor(red: 0.000, green: 0.580, blue: 0.530, alpha: 1) // deeper teal for light contrast
        }
        static let accent          = SwiftUI.Color(_accent)
        static let accentPressed   = SwiftUI.Color(_accent)
        // onAccent: white — sufficient contrast on #0DB5A4 (dark) and #00897B (light)
        static let onAccent        = SwiftUI.Color.white
```

with:

```swift
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
```

- [ ] **Step 5: Swap `accentGlow` + add the `brandGradient` token**

Replace (lines 66-71):

```swift
        // Glow — used as box-shadow color on primary actions and active states
        static let accentGlow = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.090, green: 0.918, blue: 0.851, alpha: 0.45)
                : UIColor(red: 0.000, green: 0.580, blue: 0.530, alpha: 0.25)
        })
```

with:

```swift
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
```

- [ ] **Step 6: Build**

Run the build command (top of plan).
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Visual smoke check**

Boot the app on iPhone 17 sim, open the companion app. Toggle dark/light (`xcrun simctl ui booted appearance dark|light`). Expect every accent/surface to read **warm rose/plum** instead of teal/navy. (Root window bg may still look navy at the very edges until Task 2 — that's expected.)

- [ ] **Step 8: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Shared/ReplrTheme.swift
git commit -m "Theme: re-skin ReplrTheme to Flirt Gradient palette + add brandGradient token

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Swap the two duplicated hardcoded backgrounds

`bg` is duplicated as raw `UIColor` literals in the app's root window and the keyboard's root view (these run before/around SwiftUI and can't read the token). They must match the new `bg`.

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift:24-25`
- Modify: `ReplrKeyboard/KeyboardViewController.swift:65-66`

- [ ] **Step 1: ReplrApp.swift**

Replace (lines 24-25):

```swift
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
                : UIColor(red: 0.961, green: 0.945, blue: 0.922, alpha: 1) // #F5F1EB warm cream
```

with:

```swift
                ? UIColor(red: 0.082, green: 0.063, blue: 0.102, alpha: 1) // #15101A
                : UIColor(red: 1.000, green: 0.973, blue: 0.961, alpha: 1) // #FFF8F5 warm white
```

- [ ] **Step 2: KeyboardViewController.swift**

Replace (lines 65-66) — identical text, same replacement:

```swift
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
                : UIColor(red: 0.961, green: 0.945, blue: 0.922, alpha: 1) // #F5F1EB warm cream
```

with:

```swift
                ? UIColor(red: 0.082, green: 0.063, blue: 0.102, alpha: 1) // #15101A
                : UIColor(red: 1.000, green: 0.973, blue: 0.961, alpha: 1) // #FFF8F5 warm white
```

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/Replr/App/ReplrApp.swift ReplrKeyboard/KeyboardViewController.swift
git commit -m "Swap duplicated root backgrounds to Flirt warm bg (#15101A / #FFF8F5)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Gradient `PrimaryButton` + selected `Chip`

**Files:**
- Modify: `Shared/ReplrComponents.swift:48-51` (PrimaryButton)
- Modify: `Shared/ReplrComponents.swift:204-219` (Chip)

- [ ] **Step 1: PrimaryButton fill → brand gradient**

Replace (lines 48-51):

```swift
            .background(
                Capsule()
                    .fill(ReplrTheme.Color.accent.opacity(isEnabled ? 1 : 0.40))
            )
```

with:

```swift
            .background(
                Capsule()
                    .fill(ReplrTheme.Color.brandGradient)
                    .opacity(isEnabled ? 1 : 0.40)
            )
```

- [ ] **Step 2: Chip selected state → gradient fill + onAccent text**

Replace (line 204):

```swift
            .foregroundColor(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
```

with:

```swift
            .foregroundColor(isSelected ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
```

Then replace (lines 207-210):

```swift
            .background(
                Capsule()
                    .fill(isSelected ? ReplrTheme.Color.accentSubtle : ReplrTheme.Color.surface)
            )
```

with (use `AnyShapeStyle` so a gradient and a solid color can share one `.fill`; iOS 16+):

```swift
            .background(
                Capsule()
                    .fill(isSelected
                          ? AnyShapeStyle(ReplrTheme.Color.brandGradient)
                          : AnyShapeStyle(ReplrTheme.Color.surface))
            )
```

Then replace the selected border (lines 213-217) so it doesn't fight the gradient:

```swift
                    .strokeBorder(
                        isSelected
                            ? ReplrTheme.Color.accent.opacity(0.55)
                            : ReplrTheme.Color.glassBorder,
                        lineWidth: 1
                    )
```

with:

```swift
                    .strokeBorder(
                        isSelected
                            ? Color.white.opacity(0.25)
                            : ReplrTheme.Color.glassBorder,
                        lineWidth: 1
                    )
```

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Visual check**

In the app, open History/Captures (the filter chips use `Chip`) and any screen with a `PrimaryButton`. Selected chip + primary button should show the **rose→amber gradient** with white text, in both light and dark.

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Shared/ReplrComponents.swift
git commit -m "Components: PrimaryButton + selected Chip use brand gradient

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Gradient CTAs in the keyboard idle card

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift:62-66` (Start CTA)
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift:122-126` (email CTA)

- [ ] **Step 1: "Start" CTA fill → brand gradient**

Replace (lines 62-66):

```swift
                    .background(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                            .overlay(ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm))
                    )
```

with:

```swift
                    .background(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .fill(ReplrTheme.Color.brandGradient)
                            .overlay(ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm))
                    )
```

- [ ] **Step 2: Email CTA fill → brand gradient when active**

Replace (lines 122-126):

```swift
                .background(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .fill(hasClipboardText ? ReplrTheme.Color.accent : ReplrTheme.Color.surface)
                        .overlay(hasClipboardText ? ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm) : nil)
                )
```

with:

```swift
                .background(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .fill(hasClipboardText
                              ? AnyShapeStyle(ReplrTheme.Color.brandGradient)
                              : AnyShapeStyle(ReplrTheme.Color.surface))
                        .overlay(hasClipboardText ? ShimmerOverlay(cornerRadius: ReplrTheme.Radius.sm) : nil)
                )
```

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "Keyboard: idle-card CTAs use brand gradient

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Recolor the Lottie accent (teal → rose)

The app loads the **minified embedded raw strings**, not the `.json` source files. Recolor those first (exact + verifiable), then sync the source assets for hygiene.

The distinct teal tokens in the embedded strings (confirmed by audit):
- `IdlePanelView.swift`: `[0.09,0.918,0.851]` ×2 and `[0.11,0.94,0.87]` ×1
- `OnboardingView.swift`: `[0.0902,0.9176,0.851]` ×13

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift` (embedded `captureStepsLottieJSON`)
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift` (6 embedded constants)
- Modify: `ReplrKeyboard/Resources/capture_steps.json`, `Replr/Replr/Features/Onboarding/onboarding_steps.json`, `Replr/Replr/Features/Onboarding/tutorial_lottie/tut_{switch,pick,minimise,screenshot,send}.json`

- [ ] **Step 1: Recolor `IdlePanelView.swift` embedded JSON**

Use Edit with `replace_all: true` for the base teal, and a single replace for the bright variant:

- `[0.09,0.918,0.851]` → `[1,0.435,0.569]`  (replace_all — 2 occurrences, base rose #FF6F91)
- `[0.11,0.94,0.87]` → `[1,0.588,0.682]`  (1 occurrence, bright rose #FF96AE)

- [ ] **Step 2: Recolor `OnboardingView.swift` embedded JSON**

Edit with `replace_all: true`:

- `[0.0902,0.9176,0.851]` → `[1,0.435,0.569]`  (13 occurrences, base rose #FF6F91)

- [ ] **Step 3: Verify zero teal remains in the Swift the app loads**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
rg -o -N '\[0\.[01][0-9]*,0\.9[0-9]*,0\.8[0-9]*\]' \
  ReplrKeyboard/Views/IdlePanelView.swift \
  Replr/Replr/Features/Onboarding/OnboardingView.swift | sort | uniq -c
```

Expected: **no output** (zero teal arrays left). Also confirm the new rose arrays are present:

```bash
rg -c '\[1,0\.435,0\.569\]|\[1,0\.588,0\.682\]' \
  ReplrKeyboard/Views/IdlePanelView.swift \
  Replr/Replr/Features/Onboarding/OnboardingView.swift
```

Expected: `IdlePanelView.swift:1` line match (3 tokens on its one JSON line) and `OnboardingView.swift` with matches.

- [ ] **Step 4: Recolor the canonical source `.json` assets (hygiene)**

These are pretty-printed, so recolor by structure with `jq` (handles 3- or 4-element arrays, preserves alpha). Run for each file:

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
for f in ReplrKeyboard/Resources/capture_steps.json \
         Replr/Replr/Features/Onboarding/onboarding_steps.json \
         Replr/Replr/Features/Onboarding/tutorial_lottie/tut_switch.json \
         Replr/Replr/Features/Onboarding/tutorial_lottie/tut_pick.json \
         Replr/Replr/Features/Onboarding/tutorial_lottie/tut_minimise.json \
         Replr/Replr/Features/Onboarding/tutorial_lottie/tut_screenshot.json \
         Replr/Replr/Features/Onboarding/tutorial_lottie/tut_send.json; do
  jq '(.. | objects | select(.ty? == "fl" or .ty? == "st") | .c.k) |=
        (if (type=="array" and length>=3
             and (.[0]|type)=="number" and .[0] < 0.3 and .[1] > 0.8 and .[2] > 0.8)
         then (if length==4 then [1,0.435,0.569,.[3]] else [1,0.435,0.569] end)
         else . end)' "$f" > "$f.tmp" && mv "$f.tmp" "$f" && echo "recolored $f"
done
```

> This covers static fills/strokes. Any animated-color or gradient teal in a source file is non-blocking — the source `.json` is not loaded at runtime; the embedded copy (Steps 1-2) is. Sanity-check the static ones were swapped:

```bash
jq -c '[.. | objects | select(.ty=="fl") | .c.k] | unique' ReplrKeyboard/Resources/capture_steps.json
```

Expected: the teal `[0.09,0.918,0.851]` / `[0.11,0.94,0.87]` are gone; `[1,0.435,0.569]` present; white `[1,1,1]` and gray `[0.5,0.55,0.62]` preserved.

- [ ] **Step 5: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Visual check (animations render warm)**

Keyboard idle card: the looping demo's accent shapes are now **rose**, not teal. Onboarding final celebration + the 5 tutorial steps: accent is rose. Confirm in both light and dark. (Reduce-Motion fallback uses `ReplrTheme.Color.accent` and is already rose from Task 1.)

- [ ] **Step 7: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add ReplrKeyboard/Views/IdlePanelView.swift \
        Replr/Replr/Features/Onboarding/OnboardingView.swift \
        ReplrKeyboard/Resources/capture_steps.json \
        Replr/Replr/Features/Onboarding/onboarding_steps.json \
        Replr/Replr/Features/Onboarding/tutorial_lottie/
git commit -m "Lottie: recolor accent teal -> Flirt rose (embedded + source assets)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Rewrite `DESIGN.md` for Flirt Gradient

`DESIGN.md` is the AI-facing spec other agents read before doing UI work. It must describe the new language.

**Files:**
- Modify: `DESIGN.md` (whole file)

- [ ] **Step 1: Replace the YAML front-matter `description` + `colors` block**

In the front-matter, change the `description` line "Dark-first, calm and precise, with one teal accent." to "Adaptive (dark + light), warm and flirty, with a rose→coral→amber brand gradient and a rose accent." Then replace the `colors:` block (lines 12-26) with:

```yaml
colors:
  # token: { dark, light }   (UIColor dynamic — see ReplrTheme.Color)
  bg:            { dark: "#15101A", light: "#FFF8F5" }   # warm plum-black / warm white
  surface:       { dark: "#211826", light: "#FFFFFF" }   # cards, panels
  surfaceRaised: { dark: "#2D2032", light: "#FFFFFF" }
  accent:        { dark: "#FF6F91", light: "#E8447A" }   # flirt rose (deeper on light)
  brandGradient: "#FF5E8A -> #FF7A59 -> #FFB45E"         # rose -> coral -> amber (both modes)
  onAccent:      "#FFFFFF"
  textPrimary:   "iOS .primary"        # semantic, adaptive
  textSecondary: "iOS .secondary"
  textTertiary:  "iOS .tertiaryLabel"
  glassBorder:   { dark: "white 10%", light: "black 8%" }
  accentSoft:    "accent @ 12%"
  accentGlow:    { dark: "accent @ 42%", light: "accent @ 22%" }   # shadow on actions
  danger:        "iOS .systemRed"
  success:       "iOS .systemGreen"
```

- [ ] **Step 2: Update `components.primaryButton.backgroundColor`**

Change `backgroundColor: "{colors.accent}"` (under `primaryButton:`) to `backgroundColor: "{colors.brandGradient}"`.

- [ ] **Step 3: Replace the body "Overview" + "Colors" sections**

Replace the `## Overview` bullets and `## Colors` section so they describe: adaptive (not dark-first); the **brand gradient** as the signature surface (primary CTAs, active chips, brand mark); **rose** as the solid accent for icons/selection/tints/borders; gradient used **only** on primary actions (don't gradient every surface); light mode uses deeper `#E8447A` for AA contrast. Update the colors table to:

```markdown
| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#15101A` | `#FFF8F5` | Screen background |
| `surface` | `#211826` | `#FFFFFF` | Cards, panels, rows |
| `surfaceRaised` | `#2D2032` | `#FFFFFF` | Raised cards |
| `brandGradient` | `#FF5E8A → #FF7A59 → #FFB45E` | same | Primary CTAs, active chips, brand mark |
| `accent` | `#FF6F91` | `#E8447A` | Solid rose — icons, selection, tints, borders |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | Text/icons on gradient/accent |
| `glassBorder` | white 10% | black 8% | Hairline card borders |
| `accentGlow` | accent 42% | accent 22% | Shadow color on primary actions |
```

- [ ] **Step 4: Update Components + Do's/Don'ts**

In `## Components`: PrimaryButton background is now the **brand gradient** capsule; add that selected chips use the gradient fill + `onAccent` text. In `## Do's and Don'ts`: replace "Keep teal as the single accent" / "Don't introduce a second brand hue" with: **Do** use `brandGradient` for the one primary CTA / active chip and the solid `accent` (rose) for tints; **Don't** apply the gradient to passive surfaces (cards stay `surface`) or invent a new hue outside the rose→amber ramp. Keep all other rules (tokens-only, 4pt grid, two weights, continuous corners, third-person "Replr").

- [ ] **Step 5: Verify no stale teal copy remains**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
rg -i 'teal|navy|17EAD9|009487|0D1117|F5F1EB' DESIGN.md
```

Expected: **no output**.

- [ ] **Step 6: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add DESIGN.md
git commit -m "DESIGN.md: rewrite for Flirt Gradient language

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Full sweep + light/dark verification

**Files:** none expected (fix-ups only if the sweep finds strays).

- [ ] **Step 1: Sweep for any remaining teal references**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
echo "--- teal hex / RGB literals in Swift (expect only intentional none) ---"
rg -n -i '17ead9|0\.918, *blue: *0\.851|009487|0\.580, *blue: *0\.530|0D1117|131929|1C2539|F5F1EB|FDFCFA' -g '*.swift'
echo "--- teal arrays in Lottie (embedded + source) ---"
rg -o -N '\[0\.[01][0-9]*,0\.9[0-9]*,0\.8[0-9]*\]' -g '*.swift' -g '*.json'
echo "--- the word teal anywhere ---"
rg -n -i 'teal' -g '*.swift' -g '*.json' -g '*.md'
```

Expected: no Swift/JSON color hits. Any match → recolor it to the warm equivalent and re-commit. (A stray `// teal` comment is acceptable to fix for tidiness.)

- [ ] **Step 2: Full build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run the test suite (no regressions)**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr/Replr
xcodebuild test -project Replr.xcodeproj -scheme ReplrTests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | tail -20
```

Expected: `TEST SUCCEEDED` (or unchanged from pre-redesign baseline — the redesign touches no logic).

- [ ] **Step 4: Visual sign-off — light AND dark**

Boot iPhone 17 sim. For each appearance (`xcrun simctl ui booted appearance dark`, then `light`), screenshot and confirm warm rose/plum throughout:
- App: Onboarding (Welcome → Ready → tutorial carousel), Tones, History/Captures (filter chips gradient), Settings, paywall/subscription.
- Keyboard: idle chat card (gradient Start CTA, rose animation, warm card), email mode CTA.

```bash
xcrun simctl io booted screenshot /tmp/replr-final-dark.png   # repeat for light
```

Checklist: no teal anywhere · gradient only on primary CTAs + active chips · text contrast AA in light (rose `#E8447A` on white) · animations render rose · card borders/glows warm.

- [ ] **Step 5: Final commit (if any fix-ups)**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add -A
git commit -m "Flirt Gradient: sweep fixes + verified light/dark across app, keyboard, onboarding

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-review

**Spec coverage:**
- ✅ `ReplrTheme.Color` warm swap + `brandGradient` token → Task 1
- ✅ `ReplrComponents` gradient (PrimaryButton + chips) → Task 3
- ✅ Lottie accent swappable/recolored → Task 5 (recolor approach; see note)
- ✅ `DESIGN.md` rewrite → Task 6
- ✅ Sweep hardcoded teal → Task 2 (the two bg dupes) + Task 7 (full sweep)
- ✅ Verify light + dark across app/keyboard/onboarding → Task 7
- ✅ Adaptive light + dark preserved (dynamic `UIColor` providers untouched in structure)
- ✅ Out of scope honored: no tone-name/content rewrite, no bird-mark redesign, no custom font, no marketing.

**Type consistency:** `brandGradient` is a `LinearGradient` (ShapeStyle + View) — used via `.fill(...)`, `.background(...)`, and `AnyShapeStyle(...)` for conditionals (iOS 16+, matches the app's existing `NavigationStack` baseline). The recolor tokens in Task 5 match exactly what the audit found in each file. `onAccent` stays `Color.white`.

**Notable interpretation:** there is no literal "tone chip" component (tones render as `PresetToneRow` list rows, which re-skin to rose automatically via Task 1). The spec's "active tone chip → gradient" is realized on the shared `Chip` component (Task 3), which is where chips actually appear (capture-log filters). Flagged for reviewer.
