# Onboarding Wispr Redesign — Phase 1 (Foundation + Reskin) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or
> superpowers:subagent-driven-development to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the Wispr-grade visual language (Fraunces serif headlines, restraint
palette, doodle primitives, segmented progress bar) and reskin the *existing* onboarding
steps with it — no new steps yet, no behavior changes.

**Architecture:** All work is in the **companion app** (`Replr/Replr/`) + the shared theme
(`Shared/ReplrTheme.swift`). Fraunces is bundled and registered at launch with
`CTFontManagerRegisterFontsForURL` (the targets use generated Info.plists, so no `UIAppFonts`
array exists to edit). A new `ReplrTheme.Font.serif(...)` token is the only API the views
touch — keeping the system swappable. Doodles + progress bar are small standalone views.

**Tech Stack:** SwiftUI, CoreText (`CTFontManager`), Swift Testing (`Replr/ReplrTests/`),
`xcodebuild` (iPhone 17 sim) as the build gate. Spec:
`docs/superpowers/specs/2026-06-06-onboarding-wispr-redesign.md`.

**Branch:** `onboarding-wispr-redesign` (already checked out).

**Note on verification:** Phase 1 is almost entirely visual; there is little pure logic to
unit-test (that lands in Phase 2's survey mapping). So most tasks verify by **build gate +
on-device light/dark check**, not XCTest. The one testable seam (font registration success)
gets a debug assertion.

---

### Task 1: Bundle + register Fraunces

**Files:**
- Create: `Replr/Replr/Resources/Fonts/Fraunces-SemiBold.ttf`, `…/Fraunces-Bold.ttf` (OFL)
- Create: `Replr/Replr/App/FontRegistration.swift`
- Modify: `Replr/Replr/App/ReplrApp.swift` (call registration at launch)

- [ ] **Step 1: Fetch the OFL static weights** (Fraunces, SIL Open Font License)

```bash
mkdir -p "Replr/Replr/Resources/Fonts"
# Static instances from the upstream OFL repo (undercasetype/Fraunces, mirrored on Google Fonts):
curl -fsSL -o "Replr/Replr/Resources/Fonts/Fraunces-SemiBold.ttf" \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/fraunces/static/Fraunces_72pt-SemiBold.ttf"
curl -fsSL -o "Replr/Replr/Resources/Fonts/Fraunces-Bold.ttf" \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/fraunces/static/Fraunces_72pt-Bold.ttf"
# Also vendor the license:
curl -fsSL -o "Replr/Replr/Resources/Fonts/OFL.txt" \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/fraunces/OFL.txt"
file "Replr/Replr/Resources/Fonts/"*.ttf   # expect: TrueType font data
```
Expected: two `.ttf` files (>50 KB each) + `OFL.txt`. If the path 404s, fall back to the
variable file `…/fraunces/Fraunces[SOFT,WONK,opsz,wght].ttf` and adjust names in Step 3.

> `Replr/Replr/` is a `PBXFileSystemSynchronizedRootGroup`, so files dropped here are
> auto-added to the target — no pbxproj edit needed. Confirm in Step 4's build.

- [ ] **Step 2: Registration helper**

Create `Replr/Replr/App/FontRegistration.swift`:
```swift
import CoreText
import Foundation

enum ReplrFonts {
    /// Registers bundled Fraunces weights so `Font.custom("Fraunces…")` resolves.
    /// Idempotent — safe to call once at launch.
    static func registerBundledFonts() {
        let names = ["Fraunces-SemiBold", "Fraunces-Bold"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing bundled font: \(name).ttf"); continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered is fine; log anything else in debug.
                #if DEBUG
                print("Font register note for \(name): \(String(describing: error))")
                #endif
            }
        }
    }
}
```

- [ ] **Step 3: Call at launch + verify the PostScript names**

In `Replr/Replr/App/ReplrApp.swift`, call `ReplrFonts.registerBundledFonts()` in the `App`
`init()` (before any view uses the serif). Temporarily add, in `init()`:
```swift
#if DEBUG
UIFont.familyNames.filter { $0.contains("Fraunces") }
    .forEach { print("Fraunces family:", $0, UIFont.fontNames(forFamilyName: $0)) }
#endif
```
Run the app once in the sim; read the console for the exact PostScript names (e.g.
`Fraunces-SemiBold`, `Fraunces72ptSemiBold`). Record them — Task 2 uses them. Remove the
debug print after.

- [ ] **Step 4: Build**

Run: `xcodebuild -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build 2>&1 | rg -i 'error:|BUILD SUCCEEDED|BUILD FAILED'`
Expected: `** BUILD SUCCEEDED **` and the fonts appear in the bundle.

- [ ] **Step 5: Commit**

```bash
git add Replr/Replr/Resources/Fonts Replr/Replr/App/FontRegistration.swift Replr/Replr/App/ReplrApp.swift
git commit -m "Onboarding P1: bundle + register Fraunces (OFL)"
```

---

### Task 2: `ReplrTheme.Font.serif(...)` token

**Files:**
- Modify: `Shared/ReplrTheme.swift` (the `Font` enum, ~line 104)

- [ ] **Step 1: Add the serif token** using the PostScript name confirmed in Task 1 Step 3
(shown here as `"Fraunces-SemiBold"` / `"Fraunces-Bold"` — replace if different):
```swift
// MARK: Serif display (onboarding/marketing headlines only — see DESIGN.md)
/// Fraunces serif. Falls back to the system serif (New York) if the bundle font is missing.
static func serif(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
    let face = weight >= .bold ? "Fraunces-Bold" : "Fraunces-SemiBold"
    if UIFont(name: face, size: size) != nil {
        return .custom(face, size: size)
    }
    return .system(size: size, weight: weight, design: .serif) // graceful fallback
}
static let serifDisplay = serif(34, weight: .bold)   // big carousel/claim headlines
static let serifTitle   = serif(26, weight: .semibold) // step titles
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build 2>&1 | rg -i 'error:|BUILD SUCCEEDED'`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Shared/ReplrTheme.swift
git commit -m "Onboarding P1: add ReplrTheme.Font.serif token (Fraunces + serif fallback)"
```

---

### Task 3: Doodle primitives

**Files:**
- Create: `Replr/Replr/Features/Onboarding/OnboardingDoodles.swift`

- [ ] **Step 1: Implement two amber hand-drawn annotations** as reusable views:
`DoodleCircle` (a slightly-irregular ellipse stroke) and `DoodleArrow` (a curved stroke with
an arrowhead), both tinted `ReplrTheme.Color.amber` (or `.accent` if no `amber` token —
confirm token name in `ReplrTheme` first; add an `amber` alias if missing). Use
`StrokeStyle(lineWidth: 3, lineCap: .round)`. Keep them parameterized by size. Include
`#Preview`s for both on light + dark.

- [ ] **Step 2: Build + eyeball the previews** (Xcode canvas, both color schemes).

Run: `xcodebuild … build` (same gate). Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Replr/Replr/Features/Onboarding/OnboardingDoodles.swift
git commit -m "Onboarding P1: amber doodle primitives (circle, arrow)"
```

---

### Task 4: Segmented progress bar

**Files:**
- Create: `Replr/Replr/Features/Onboarding/OnboardingProgressBar.swift`

- [ ] **Step 1: Implement** `OnboardingProgressBar(current: Int, total: Int)` — `total`
rounded capsules in an `HStack`; the first `current` filled with `ReplrTheme.Color.accent`,
the rest `textSecondary.opacity(0.25)`. Animate fill with `.easeInOut`. `#Preview` at a few
`(current,total)` values, light + dark.

- [ ] **Step 2: Build.** Same gate → `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Replr/Replr/Features/Onboarding/OnboardingProgressBar.swift
git commit -m "Onboarding P1: segmented progress bar"
```

---

### Task 5: Reskin the `OnboardingStep` wrapper + `WelcomeStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`
  (`OnboardingStep` ~line 15; `WelcomeStep` ~line 95)

- [ ] **Step 1: Serif titles in the wrapper.** In `OnboardingStep`, render the title with
`ReplrTheme.Font.serifTitle` (was a system bold). Keep body/CTA on the existing sans tokens.
Increase top margin / whitespace per the language (generous top padding, one idea per
screen).

- [ ] **Step 2: Restraint pass on `WelcomeStep`.** Apply serif headline, reduce gradient to
the single primary CTA only, add an amber highlight to one key word
(`Text` + `.foregroundStyle(ReplrTheme.Color.accent)` on a concatenated run). Leave the
no-op "I have an account" button untouched for now (separate cleanup; out of scope here).

- [ ] **Step 3: Build + light/dark device/sim check.** Same gate → `BUILD SUCCEEDED`; eyeball
both schemes.

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/Features/Onboarding/OnboardingView.swift
git commit -m "Onboarding P1: serif titles + restraint on step wrapper + Welcome"
```

---

### Task 6: Reskin `KeyboardSetupStep` (priming)

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift` (`KeyboardSetupStep` ~line 294)

- [ ] **Step 1:** Serif title; add a dark **"Your data is safe"** priming card (amber on
*safe*) with a one-line reassurance above/below the existing `KeyboardSettingsPreview`
faux-toggle. Keep the existing enable + Full-Access detection and CTA behavior unchanged.
Add a `DoodleArrow` pointing at the faux toggle.

- [ ] **Step 2: Build + light/dark check.** Same gate → `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Replr/Replr/Features/Onboarding/OnboardingView.swift
git commit -m "Onboarding P1: reskin KeyboardSetupStep with priming card + doodle"
```

---

### Task 7: Reskin `PhotosPermissionStep` (priming) + `ReadyStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`
  (`PhotosPermissionStep` ~line 347; `ReadyStep` ~line 440)

- [ ] **Step 1: PhotosPermissionStep** — same priming treatment: serif title, a
"Replr only reads the chat you show it" reassurance card (amber on one word), keep the
existing `PhotosSettingsPreview` + privacy bullets + permission flow.

- [ ] **Step 2: ReadyStep** — serif celebration headline; keep the centered layout; trim any
gradient to the single CTA. (The sample-demo hand-off lands in Phase 3 — leave the existing
`onDone` wiring.)

- [ ] **Step 3: Build + light/dark check.** Same gate → `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/Features/Onboarding/OnboardingView.swift
git commit -m "Onboarding P1: reskin Photos + Ready steps (serif, priming, restraint)"
```

---

### Task 8: Update DESIGN.md

**Files:**
- Modify: `DESIGN.md` (Typography section ~line 116; the "No custom fonts" line 126)

- [ ] **Step 1:** Replace "No custom fonts" with the new rule: **system sans (SF Pro) for all
body/UI; Fraunces serif via `ReplrTheme.Font.serif(...)` for onboarding/marketing display
headlines only.** Add the `serifDisplay` / `serifTitle` tokens to the typography list. Note
the restraint rule (amber highlights one word; gradient only on the primary CTA) and that
doodles + the progress bar are onboarding-scoped components.

- [ ] **Step 2: Commit**

```bash
git add DESIGN.md
git commit -m "Onboarding P1: DESIGN.md — serif display tokens + restraint rules"
```

---

## Self-Review

**1. Spec coverage (Phase 1 scope):** Fraunces bundle/register (T1) ✓ · serif token (T2) ✓ ·
doodles (T3) ✓ · progress bar (T4) ✓ · reskin Welcome/Keyboard/Photos/Ready (T5–T7) ✓ ·
DESIGN.md (T8) ✓. New steps (carousel, survey, Back Tap, sample demo) are intentionally
Phase 2/3 — not in this plan. No Phase 1 spec item is unmapped.

**2. Placeholder scan:** No "TBD/implement-later." The only deferrals are explicit and safe:
the exact Fraunces PostScript name is *measured* in T1·S3 and threaded into T2; the `amber`
token name is confirmed in T3·S1 (alias added if missing). Both are verification steps, not
hand-waves.

**3. Type consistency:** `ReplrFonts.registerBundledFonts()` (T1) ↔ called in T1·S3.
`ReplrTheme.Font.serif(_:weight:)` + `serifDisplay`/`serifTitle` defined in T2, consumed in
T5–T7. `OnboardingProgressBar(current:total:)` (T4) — not yet mounted (wiring is Phase 2 when
steps are added); flagged so it isn't assumed live. `DoodleCircle`/`DoodleArrow` (T3) consumed
in T6.

**Note:** the progress bar (T4) is *built* in Phase 1 but only *mounted* in Phase 2 once the
new steps exist and the step/total count is known — building it now keeps the foundation
complete.
