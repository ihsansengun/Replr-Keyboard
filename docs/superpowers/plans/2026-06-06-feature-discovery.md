# Feature-Discovery & Mental-Model — Implementation Plan

> **For agentic workers:** execute inline (same session). Steps use checkbox syntax.

**Goal:** Stop the steer coachmark firing on launch #1; surface steer/Back Tap by competence
milestones (one at a time); add the "Replr generates, your keyboard types" mental-model line.

**Architecture:** A pure `KeyboardTipCoordinator` (Shared, unit-tested) decides the single tip
from milestones held in `AppGroupService`. `IdlePanelView` renders whichever tip the
coordinator returns. Onboarding gains a mental-model line.

**Tech Stack:** Swift / SwiftUI, App Group `UserDefaults`, XCTest (`ReplrTests`), build gate iPhone 17 sim.

**Refinement vs spec:** Keep the steer step in `UsageTutorialView` (it's user-paced and doubles
as the revisitable reference / fallback B). The intrusive thing the user flagged was the
*keyboard coachmark* on first attempt — that's what gets milestone-gated. Onboarding's
substantive change is the mental-model line.

---

### Task 1: Milestones + tip state in AppGroupService

**Files:** Modify `Shared/Constants.swift`, `Shared/AppGroupService.swift`

- [ ] Constants: add keys `sessionRegenerateCountKey`, `tipDismissedPrefix` ("tip_dismissed_"),
      `tipShowCountPrefix` ("tip_show_count_").
- [ ] AppGroupService: `var sessionRegenerateCount: Int` (get/set); reset to 0 inside
      `appendCaptureSession(_:)` (single chokepoint for new captures).
- [ ] AppGroupService: `tipDismissed(_ id: String) -> Bool` / `setTipDismissed(_ id:)`,
      `tipShowCount(_ id:) -> Int` / `incrementTipShowCount(_ id:)`.
- [ ] Build (app scheme). Commit.

### Task 2: KeyboardTipCoordinator (TDD)

**Files:** Create `Shared/KeyboardTipCoordinator.swift`, `ReplrTests/KeyboardTipCoordinatorTests.swift`

API:
```swift
enum KeyboardTip: Equatable { case none, steer, backTap }
enum KeyboardTipCoordinator {
    static let maxSteerShows = 3
    static let maxBackTapShows = 3
    static func currentTip(captureCount: Int, sessionRegenerateCount: Int,
                           steerDismissed: Bool, steerShowCount: Int,
                           backTapDismissed: Bool, backTapShowCount: Int,
                           isChatMode: Bool) -> KeyboardTip
}
```
Rules: not chat → `.none`. `steerRetired = steerDismissed || steerShowCount >= 3`.
`steerEligible = captureCount >= 2 || sessionRegenerateCount >= 2`. If eligible && !retired → `.steer`.
Else `backTapRetired = backTapDismissed || backTapShowCount >= 3`; if `captureCount >= 5 && steerRetired && !backTapRetired` → `.backTap`. Else `.none`.

- [ ] Write `KeyboardTipCoordinatorTests` (matrix): not-chat→none; (0,0)→none; (2,0)→steer;
      (1,2)→steer; (2,0,steerDismissed)→none; (5,0,steer not retired)→steer (steer first);
      (5,0,steerShowCount3)→backTap; (5,0,steerDismissed)→backTap;
      (5,0,steerDismissed,backTapDismissed)→none; (5,0,steerDismissed,backTapShowCount3)→none.
- [ ] Run `xcodebuild test -scheme ReplrTests` → fails (no type). Implement. Re-run → pass.
- [ ] Commit.

### Task 3: Increment regenerate counter on the keyboard regenerate path

**Files:** Modify `ReplrKeyboard/Views/KeyboardView.swift` (KeyboardModel `regenerateReplies()` + email variant)

- [ ] At the start of each regenerate method: `AppGroupService.shared.sessionRegenerateCount += 1`.
- [ ] Build. Commit.

### Task 4: IdlePanelView — coordinator-driven tips

**Files:** Modify `ReplrKeyboard/Views/IdlePanelView.swift`

- [ ] Replace the `intentTipShowCount < 3` gate (onAppear) with:
      compute `tip = KeyboardTipCoordinator.currentTip(...)` from AppGroupService milestones +
      `isChatMode: model.inputMode == .chat`; on appear, increment the shown tip's showCount once per launch.
- [ ] Reword the steer coachmark copy to the mental-model wording (spec).
- [ ] Add a dismissible Back Tap banner (same balloon style) shown when `tip == .backTap`;
      profiles-first copy; tapping opens `BackTapSetupFullView` (via existing `replr://setup`
      open-URL or a sheet). ✕ calls `setTipDismissed("backTap")`.
- [ ] Steer ✕ calls `setTipDismissed("steer")` (replaces the old `intentTipShowCount = 3`).
- [ ] Build (app scheme, builds keyboard). Commit.

### Task 5: Onboarding mental-model line

**Files:** Modify `Replr/Replr/Features/Onboarding/OnboardingView.swift`

- [ ] Add the mental-model line on the first usage-tutorial step (the switch step), aligning
      gesture wording to the real long-press-globe gesture:
      "Replr writes your replies — it isn't for typing. Type with your normal keyboard; hold 🌐
      to bring up Replr when you want a reply."
- [ ] Build. Commit.

### Task 6: Verify

- [ ] `xcodebuild test -scheme ReplrTests` green; app build green; spot-check light + dark.

## Self-review
- Spec coverage: stages 0/2/3 → Tasks 5/4/4; coordinator → Task 2; milestones → Tasks 1/3; fallback B → kept via UsageTutorialView (refinement). ✓
- Type consistency: `KeyboardTip`, `currentTip(...)`, tip ids "steer"/"backTap" consistent across tasks. ✓
- Placeholders: none.
