# Back Tap Auto-Carousel — Design Spec

**Date:** 2026-06-03  
**Scope:** `BackTapStep` in `Replr/Replr/Features/Onboarding/BackTapStepView.swift`  
**Status:** Approved — ready for implementation planning

---

## Problem

The current Back Tap setup step (step 4/4) requires the user to manually tap "Next →" through 5 sub-steps before they can tap "Open Settings →". This adds friction: a user who just wants to open Settings has to tap through 5 screens first. Additionally, users who don't read each screen carefully miss the path they need to follow.

---

## Solution

Replace the manual "Next →" sub-step navigation with an auto-cycling carousel. The panel advances automatically so the user sees the full Settings path as a looping animation. Manual swipe and back-button navigation are preserved so the user can still control it if they want.

---

## Behaviour

### Auto-cycle

- The panel auto-advances to the next sub-step every **2.2 seconds**
- After sub-step 5, it loops back to sub-step 1
- The timer **resets** whenever the user navigates manually (so manual navigation always gives a full 2.2 s before the next auto-advance)

### Manual navigation

- **Swipe left** on the panel → advance to next sub-step (wraps: step 5 → step 1)
- **Swipe right** on the panel → go back to previous sub-step (wraps: step 1 → step 5)
- **Header back button at sub-step 1** → exits the Back Tap step entirely, navigating back to `InstallShortcutStep` (calls `onBack`)
- **Header back button at sub-steps 2–5** → steps back within the panel (sub-step N → N-1); timer resets

### CTA

- A single **"Open Settings →"** primary button is visible at all times during the preview phase, regardless of which sub-step is showing
- "Already set up →" tertiary button remains (advances to the Confirm state)
- The current "Next →" button (shown on sub-steps 1–4) is **removed**

### Confirm and Success states

Unchanged from the current implementation:
- **Confirm** (`state == .confirm`): pulsing phone icon, "Test the gesture." — "Skip for now →" CTA
- **Success** (`state == .success`): checkmark, "Back Tap is live." — "Start using Replr →" CTA

---

## Sub-step dot indicator

The existing `SubStepDots` component (current dot = wide capsule, inactive = small circle) stays. It is rendered at the top of the ios-panel content, as it is today. The active dot updates immediately on both auto-advance and manual navigation.

---

## Transition animation

- **Direction:** always slides left-to-right on advance (forward), right-to-left on step-back — same asymmetric transition as today
- **Duration:** `0.25 s` easeInOut (unchanged)
- On **wrap-around** (step 5 → step 1 via auto-cycle): slide forward (left) — treat as advancing, not going back

---

## State machine changes

### Remove
- `if substep < 5 { PrimaryButton("Next →") }` CTA branch — replaced by always-visible "Open Settings →" + "Already set up →"

### Keep unchanged
- `goingForward: Bool` — still drives the asymmetric slide transition direction

### Add
- `@State private var carouselTimer: Timer?`
- `startCarouselTimer()` helper: invalidates any existing timer, schedules a new repeating `Timer` at 2.2 s on the main run loop that auto-advances `substep` (with wrap-around and `goingForward = true`)
- `stopCarouselTimer()` helper: invalidates and nils the timer
- Timer lifecycle:
  - **Start** in `.onAppear` (if state is `.preview`) and whenever entering `.preview` from Confirm/back navigation
  - **Stop** when transitioning to `.confirm` or `.success`
  - **Restart** (call `startCarouselTimer()`) after any manual sub-step navigation — both swipe gesture and header back button

### Swipe gesture
The existing `DragGesture(minimumDistance: 40)` on the panel is kept with wrap-around added: swipe left on sub-step 5 → sub-step 1 (`goingForward = true`), swipe right on sub-step 1 → sub-step 5 (`goingForward = false`). After updating substep, call `startCarouselTimer()` to reset the interval.

---

## Files changed

| File | Change |
|------|--------|
| `Replr/Replr/Features/Onboarding/BackTapStepView.swift` | Remove "Next →" CTA branch; add auto-advance timer; timer resets on manual navigate; wrap-around on swipe; CTA always shows "Open Settings →" |

No other files are touched. The 5 `BackTapSubStep` view structs, `BackTapConfirmScreen`, `BackTapSuccessScreen`, and all `IOSMock` components are unchanged.

---

## Out of scope

- Redesign of other onboarding steps (Welcome, Add Keyboard, Full Access, Install Shortcut) — follow-on work
- Any changes to the Confirm or Success state UI
- Lottie or video animation — decided against due to i18n requirement; SwiftUI mockups are localisation-native
