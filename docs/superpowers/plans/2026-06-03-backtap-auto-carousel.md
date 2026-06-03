# Back Tap Auto-Carousel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the manual "Next →" sub-step navigation in `BackTapStep` with an auto-cycling carousel that loops through all 5 iOS Settings screens, while preserving swipe and back-button manual control.

**Architecture:** `BackTapStep` gains a `lastNavTime: Date` timestamp. A timer that already fires every 1.5 s (for intent polling) is extended to also call `autoAdvanceCarousel()`, which advances the substep if ≥ 2.2 s have elapsed since the last manual or automatic navigation. Manual navigation (swipe, back button) resets the timestamp. Two static helpers — `nextSubstep(from:)` and `prevSubstep(from:)` — encapsulate the wrap-around arithmetic and are unit-tested.

**Tech Stack:** SwiftUI, Swift Testing (`@Test` / `#expect`), `Timer.publish` (already in use)

---

## File Map

| File | Change |
|------|--------|
| `Replr/Replr/Features/Onboarding/BackTapStepView.swift` | Add static helpers, `lastNavTime` state, `autoAdvanceCarousel()`, update CTA, swipe gesture, back action |
| `Replr/ReplrTests/ReplrTests.swift` | Add `BackTapCarouselTests` for wrap-around helpers |

No other files touched. `BackTapSubStep1–5`, `BackTapConfirmScreen`, `BackTapSuccessScreen`, and all `IOSMock` components are unchanged.

---

## Task 1: Write failing tests for wrap-around helpers

**Files:**
- Modify: `Replr/ReplrTests/ReplrTests.swift`

- [ ] **Open `Replr/ReplrTests/ReplrTests.swift` and append the following struct** after the existing `ReplrTests` struct:

```swift
struct BackTapCarouselTests {

    // nextSubstep: 1→2, 4→5, 5→1 (wrap)
    @Test func nextSubstepAdvances() {
        #expect(BackTapStep.nextSubstep(from: 1) == 2)
        #expect(BackTapStep.nextSubstep(from: 4) == 5)
    }

    @Test func nextSubstepWrapsAtFive() {
        #expect(BackTapStep.nextSubstep(from: 5) == 1)
    }

    // prevSubstep: 3→2, 5→4, 1→5 (wrap)
    @Test func prevSubstepGoesBack() {
        #expect(BackTapStep.prevSubstep(from: 3) == 2)
        #expect(BackTapStep.prevSubstep(from: 5) == 4)
    }

    @Test func prevSubstepWrapsAtOne() {
        #expect(BackTapStep.prevSubstep(from: 1) == 5)
    }
}
```

- [ ] **Run tests — confirm they fail** because `BackTapStep.nextSubstep` and `BackTapStep.prevSubstep` don't exist yet:

```bash
xcodebuild test \
  -project Replr/Replr.xcodeproj \
  -scheme ReplrTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: compiler error — `type 'BackTapStep' has no member 'nextSubstep'`

---

## Task 2: Add static wrap-around helpers to `BackTapStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/BackTapStepView.swift`

- [ ] **Find the `// MARK: - BackTapStep (public — used by OnboardingView.swift)` comment** (line ~553) and add the following two static methods **inside** `BackTapStep`, directly after the `@State private var goingForward = true` line:

```swift
// MARK: - Carousel helpers (internal for testability)

/// Advances to the next sub-step, wrapping 5 → 1.
static func nextSubstep(from current: Int) -> Int {
    current < 5 ? current + 1 : 1
}

/// Steps back to the previous sub-step, wrapping 1 → 5.
static func prevSubstep(from current: Int) -> Int {
    current > 1 ? current - 1 : 5
}
```

- [ ] **Run the tests again — confirm they all pass:**

```bash
xcodebuild test \
  -project Replr/Replr.xcodeproj \
  -scheme ReplrTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: `Test Suite ... passed`

- [ ] **Commit:**

```bash
git add Replr/Replr/Features/Onboarding/BackTapStepView.swift \
        Replr/ReplrTests/ReplrTests.swift
git commit -m "feat: add BackTapStep wrap-around helpers with tests"
```

---

## Task 3: Add `lastNavTime` state and `autoAdvanceCarousel()` method

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/BackTapStepView.swift`

The carousel auto-advance works by timestamp: a timer that already fires every 1.5 s checks whether ≥ 2.2 s have elapsed since the last navigation (manual or automatic). If yes, it advances and resets the timestamp.

- [ ] **Add `lastNavTime` state** directly after `@State private var goingForward = true`:

```swift
/// Timestamp of the last carousel navigation — used to pace auto-advance.
@State private var lastNavTime: Date = Date()
```

- [ ] **Add `autoAdvanceCarousel()` method** in the `// MARK: - Actions` section (near `openSettings()` and `handleScenePhaseChange()`):

```swift
private func autoAdvanceCarousel() {
    guard case .preview(let substep) = state,
          Date().timeIntervalSince(lastNavTime) >= 2.2 else { return }
    lastNavTime = Date()
    goingForward = true
    withAnimation(.easeInOut(duration: 0.25)) {
        state = .preview(substep: BackTapStep.nextSubstep(from: substep))
    }
}
```

- [ ] **Update the existing `.onReceive` call** in `body` to also call `autoAdvanceCarousel()`. The current line is:

```swift
.onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
    pollForIntentFire()
}
```

Replace it with:

```swift
.onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
    pollForIntentFire()
    autoAdvanceCarousel()
}
```

- [ ] **Update `.onAppear`** to reset `lastNavTime` so the carousel waits 2.2 s before the first auto-advance. The current block is:

```swift
.onAppear {
    if AppGroupService.shared.backTapSetupStarted {
        state = .confirm
        confirmEnteredAt = Date()
    }
}
```

Replace with:

```swift
.onAppear {
    lastNavTime = Date()
    if AppGroupService.shared.backTapSetupStarted {
        state = .confirm
        confirmEnteredAt = Date()
    }
}
```

- [ ] **Build to confirm no errors:**

```bash
xcodebuild build \
  -project Replr/Replr.xcodeproj \
  -scheme Replr \
  -sdk iphonesimulator \
  -configuration Debug \
  2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

---

## Task 4: Update the CTA — remove "Next →", always show "Open Settings →"

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/BackTapStepView.swift`

- [ ] **Find `ctaView`** and replace the entire `.preview` case. The current block is:

```swift
case .preview(let substep):
    if substep < 5 {
        PrimaryButton(label: "Next →") {
            goingForward = true
            withAnimation(.easeInOut(duration: 0.25)) {
                state = .preview(substep: substep + 1)
            }
        }
    } else {
        VStack(spacing: 12) {
            PrimaryButton(label: "Open Settings →") {
                openSettings()
            }
            TertiaryButton(label: "Already set up →") {
                state = .confirm
                confirmEnteredAt = Date()
            }
        }
    }
```

Replace with:

```swift
case .preview:
    VStack(spacing: 12) {
        PrimaryButton(label: "Open Settings →") {
            openSettings()
        }
        TertiaryButton(label: "Already set up →") {
            state = .confirm
            confirmEnteredAt = Date()
        }
    }
```

- [ ] **Build:**

```bash
xcodebuild build \
  -project Replr/Replr.xcodeproj \
  -scheme Replr \
  -sdk iphonesimulator \
  -configuration Debug \
  2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

---

## Task 5: Update swipe gesture — wrap-around and timer reset

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/BackTapStepView.swift`

- [ ] **Find the `DragGesture.onEnded` closure** inside `contentView`. The current block is:

```swift
.gesture(
    DragGesture(minimumDistance: 40)
        .onEnded { value in
            let isLeftSwipe = value.translation.width < -60
            let isRightSwipe = value.translation.width > 60
            if isLeftSwipe, substep < 5 {
                goingForward = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    state = .preview(substep: substep + 1)
                }
            } else if isRightSwipe, substep > 1 {
                goingForward = false
                withAnimation(.easeInOut(duration: 0.25)) {
                    state = .preview(substep: substep - 1)
                }
            }
        }
)
```

Replace with:

```swift
.gesture(
    DragGesture(minimumDistance: 40)
        .onEnded { value in
            let isLeftSwipe = value.translation.width < -60
            let isRightSwipe = value.translation.width > 60
            if isLeftSwipe {
                lastNavTime = Date()
                goingForward = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    state = .preview(substep: BackTapStep.nextSubstep(from: substep))
                }
            } else if isRightSwipe {
                lastNavTime = Date()
                goingForward = false
                withAnimation(.easeInOut(duration: 0.25)) {
                    state = .preview(substep: BackTapStep.prevSubstep(from: substep))
                }
            }
        }
)
```

- [ ] **Build:**

```bash
xcodebuild build \
  -project Replr/Replr.xcodeproj \
  -scheme Replr \
  -sdk iphonesimulator \
  -configuration Debug \
  2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

---

## Task 6: Update back button — timer reset + Confirm→Preview reset

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/BackTapStepView.swift`

- [ ] **Find `backAction`**. The current block is:

```swift
private var backAction: (() -> Void)? {
    switch state {
    case .preview(let substep):
        if substep == 1 { return onBack }
        return {
            goingForward = false
            withAnimation(.easeInOut(duration: 0.25)) {
                state = .preview(substep: substep - 1)
            }
        }
    case .confirm:
        return { state = .preview(substep: 5) }
    case .success:
        return nil
    }
}
```

Replace with:

```swift
private var backAction: (() -> Void)? {
    switch state {
    case .preview(let substep):
        if substep == 1 { return onBack }
        return {
            lastNavTime = Date()
            goingForward = false
            withAnimation(.easeInOut(duration: 0.25)) {
                state = .preview(substep: BackTapStep.prevSubstep(from: substep))
            }
        }
    case .confirm:
        return {
            lastNavTime = Date()
            state = .preview(substep: 5)
        }
    case .success:
        return nil
    }
}
```

Note: `prevSubstep(from: substep)` is used instead of `substep - 1` for consistency — both produce the same result for substeps 2–5, but using the helper keeps the arithmetic in one place.

- [ ] **Final build:**

```bash
xcodebuild build \
  -project Replr/Replr.xcodeproj \
  -scheme Replr \
  -sdk iphonesimulator \
  -configuration Debug \
  2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Run full test suite to confirm no regressions:**

```bash
xcodebuild test \
  -project Replr/Replr.xcodeproj \
  -scheme ReplrTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: all tests pass

- [ ] **Commit:**

```bash
git add Replr/Replr/Features/Onboarding/BackTapStepView.swift
git commit -m "feat: back tap sub-steps auto-cycle carousel

- Removes manual Next → button from sub-steps 1–4
- Carousel auto-advances every ~2.2 s using lastNavTime timestamp
- Swipe left/right wraps around (5→1 and 1→5)
- Back button resets carousel timer on sub-step navigation
- Single Open Settings → CTA always visible during preview

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Manual verification checklist

Run the app on a simulator (iPhone 16, iOS 18). Navigate to the Back Tap step (step 04/04).

- [ ] Sub-step 1 appears on load; after ~2.2 s it automatically slides to sub-step 2
- [ ] Carousel loops: sub-step 5 auto-advances back to sub-step 1
- [ ] Swipe left on sub-step 5 → wraps to sub-step 1 (no dead end)
- [ ] Swipe right on sub-step 1 → wraps to sub-step 5 (no dead end)
- [ ] After any swipe, the carousel waits ~2.2 s before the next auto-advance
- [ ] "Open Settings →" button is visible on all 5 sub-steps (not just sub-step 5)
- [ ] "Already set up →" tertiary button is visible on all 5 sub-steps
- [ ] Back button at sub-step 1 → navigates back to Install Shortcut step
- [ ] Back button at sub-step 3 → goes to sub-step 2, timer resets
- [ ] Back button in Confirm state → returns to sub-step 5, carousel resumes
- [ ] Confirm and Success states are visually unchanged
- [ ] `SubStepDots` indicator updates correctly on both auto and manual navigation
