# Back Tap Onboarding Redesign

**Date:** 2026-05-26
**Goal:** Reduce drop-off at the Back Tap setup step in onboarding by replacing the current text breadcrumb + unverifiable "Done →" with a visual step-by-step guide and a live gesture confirmation.

---

## Problem

The current `BackTapStep` (step 4 of 4 in `OnboardingView`) has two fundamental gaps:

1. **No guidance inside Settings.** The path `Accessibility → Touch → Back Tap → Triple Tap` is shown as a text breadcrumb. Users get lost or give up.
2. **No verification.** "Done →" advances onboarding regardless of whether Back Tap was actually configured. Apple provides no public API to check.

Additionally, the "Skip for now — use Shortcuts.app instead" escape hatch was confusing and has no real fallback value. It is removed.

**Platform constraints confirmed:**
- `prefs:root=ACCESSIBILITY` deep link is a private API — App Store rejection under Guideline 2.5.1. Not usable.
- No public API exists to detect Back Tap configuration.
- Indirect verification is possible: `GenerateReplyIntent` writes a timestamp to AppGroup when it runs. Polling this after a live tap-gesture test acts as confirmation.

---

## Design

### Overall structure

Onboarding remains 3 steps. Step 3 (Back Tap) is completely redesigned. Steps 1 and 2 are unchanged.

```
Step 1 — Add keyboard        (deep-linkable, verifiable via AppGroup)
Step 2 — Install shortcut    (one-click iCloud URL, verifiable)
Step 3 — Back Tap            (redesigned — see below)
```

---

### Step 3 — Two phases

#### Phase 1: Visual rehearsal (4 sub-steps, all in-app)

Each sub-step uses the existing `OnboardingStep` layout. The content area shows a full-width simulated iOS Settings card — one row highlighted in teal — exactly matching what the user will see on their screen. Navigation: "Next →" / "Back ←". Settings is not opened until sub-step 4.

| Sub-step | Screen simulated | Row highlighted | CTA |
|---|---|---|---|
| 1 of 4 | Accessibility | **Touch** | Next → |
| 2 of 4 | Touch | **Back Tap** | Next → |
| 3 of 4 | Back Tap | **Double Tap** (recommended) | Next → |
| 4 of 4 | Double Tap | **Replr Capture** | Open Settings → |

**Sub-step 3 note:** Double Tap is the recommended default (fewer taps). Triple Tap is shown dimmed with a note: *"Use Triple Tap if you find Double Tap triggers accidentally."* Body text: *"Double Tap is one less tap. Either works — pick what feels right."* The user selects their preference in Settings; the walkthrough defaults to showing the Double Tap path.

#### Phase 2: Confirm + success

When "Open Settings →" is tapped on sub-step 4, three things happen simultaneously:

1. `backTapSetupStarted = true` is written to AppGroup.
2. A local notification is scheduled (fires after 8 seconds): *"Back Tap path: Accessibility → Touch → Back Tap → Double Tap → Replr Capture"* — acts as a cheat sheet in notification center while the user navigates Settings.
3. `UIApplication.openSettingsURLString` is opened.

When the user returns to the app, `scenePhase` change (`.background → .active`) with `backTapSetupStarted == true` transitions to the **confirm screen**.

**Confirm screen:**
- Headline: *"Test the gesture."*
- Body: *"Tap the back of your phone now — double or triple, whichever you chose — to confirm it's wired up."*
- Animated pulsing ring to draw attention to the gesture
- Polls AppGroup every 1.5s for `lastIntentFiredAt > confirmEnteredAt`
- On detection: auto-advances to success, clears `backTapSetupStarted`, cancels the notification
- "Skip for now →" button available (sets `backTapSkipped = true`, completes onboarding)

**Success screen:**
- Headline: *"Back Tap is live."*
- Body: *"Tap from any chat. Replies appear in your keyboard instantly."*
- Checkmark confirmation
- CTA: *"Start using Replr →"* — completes onboarding

---

### State machine

`BackTapStep` manages an internal state enum:

```swift
enum BackTapSetupState {
    case preview(substep: Int)  // substep 1–4
    case confirm
    case success
}
```

Transitions:
- `.preview(4)` → `.confirm`: triggered by `scenePhase` `.background → .active` when `backTapSetupStarted == true`
- `.confirm` → `.success`: triggered by AppGroup poll detecting `lastIntentFiredAt > confirmEnteredAt`
- Any state → onboarding complete: "Skip for now →" on confirm, or "Start using Replr →" on success

---

### AppGroup keys

| Key | Type | Written by | Read by |
|---|---|---|---|
| `backTapSetupStarted` | `Bool` | `BackTapStep` (on "Open Settings →") | `BackTapStep` (on foreground return) |
| `lastIntentFiredAt` | `Date?` | `GenerateReplyIntent` (each run) | `BackTapStep` confirm polling |

`lastIntentFiredAt` may already exist or be trivially added to `GenerateReplyIntent.perform()`.

---

### Local notification

- Requested via `UNUserNotificationCenter.requestAuthorization` if not already granted (non-blocking — if denied, notification simply doesn't appear; the design still works)
- Identifier: `"replr.backtap.reminder"` — cancelled on success or skip
- Content: title *"Back Tap reminder"*, body *"Accessibility → Touch → Back Tap → Double Tap (or Triple Tap) → Replr Capture"*
- Fire delay: 8 seconds after "Open Settings →" is tapped

---

## What is removed

- The "Skip for now — use Shortcuts.app instead" button (confusing, no real fallback)
- The `backTapSkipped` AppGroup flag usage in the Back Tap step (the skip now just completes onboarding normally)
- The `BackTapSetupFullView` sheet triggered from `replr://setup` deep link can be kept as-is for Settings re-entry later, but is out of scope for this redesign

---

## Files affected

| File | Change |
|---|---|
| `Replr/Features/Onboarding/OnboardingView.swift` | Rewrite `BackTapStep` |
| `Shared/AppGroupService.swift` | Add `backTapSetupStarted` key; add/confirm `lastIntentFiredAt` key |
| `Shared/Constants.swift` | Add new AppGroup key constants |
| `Replr/Intents/GenerateReplyIntent.swift` | Write `lastIntentFiredAt` timestamp on each `perform()` |
