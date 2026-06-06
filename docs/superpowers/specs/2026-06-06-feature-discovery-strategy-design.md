# Feature-Discovery & Mental-Model Strategy — Design

**Date:** 2026-06-06
**Status:** Approved (design); pending spec review → plan

## Problem

Two confusions are tangled together:

1. **Premature advanced features.** The intent/"steer the reply" coachmark fires on the
   keyboard's first launches (`intentTipShowCount < 3`) — before the user has felt the
   basic capture → replies → insert loop even once. Onboarding *also* front-loads
   switch + capture + steer all at once. New users are taught a power feature before the
   core magic lands.
2. **A keyboard that doesn't type.** Replr is a custom keyboard that *generates replies*,
   not a typing keyboard. Users must type input with their native keyboard (switch via 🌐)
   and bring up Replr to generate. This isn't made explicit.

These converge: **steering *is* the mental model in action** — "draft your gist with your
own keyboard → switch to Replr → it shapes the reply." Teaching the feature teaches the model.

## Principles

- **Progressive disclosure.** One concept lands before the next is introduced.
- **Gate on competence, not time.** Use real milestones (captures completed, inserts,
  regenerates) — never raw launch count.
- **One tip at a time, never stacked.** A single coordinator decides the one tip (if any) to show.
- **Let the magic land first.** The first session's only job is the "wow" of a great reply.
- **Nothing permanently undiscoverable.** A revisitable reference covers every feature.

## Approach

Chosen blend (from approaches A/B/C considered during brainstorming):

- **A — Milestone-gated tips (backbone).** Each feature surfaces after a competence milestone.
- **C — One contextual trigger.** The steer tip *also* fires after the user hits Regenerate
  twice in a session ("not quite right? steer it instead") — a natural teachable moment.
- **B — Passive fallback.** The existing revisitable "How to use Replr" tutorial (Settings)
  is the always-available reference; ensure it covers steer + Back Tap.

## The discovery ladder

| Stage | Trigger | Surface |
|---|---|---|
| **0 — Onboarding** | first run | Teach only "get Replr up + capture." Add the mental-model line (below). **Remove the steer step from required onboarding** (it moves to Stage 2). |
| **1 — First magic** | first capture | **No tips.** Pure capture → replies → insert. |
| **2 — Steer** | `captureCount ≥ 2` **or** `sessionRegenerateCount ≥ 2` | Reworded intent coachmark on the idle card. |
| **3 — Back Tap** | `captureCount ≥ 5` **and** steer tip retired | Dismissible idle-card banner, profiles-first pitch. |

### Locked decisions

1. **Milestones:** steer at `captureCount ≥ 2` OR `sessionRegenerateCount ≥ 2`; Back Tap at
   `captureCount ≥ 5`. (`captureCount` = `loadCaptureSessions().count`.)
2. **Mental-model line:** lives in **onboarding** (Stage 0) and is reinforced by the steer
   tip's wording. No separate persistent in-keyboard hint (the idle caption already nudges).
3. **Back Tap pitch:** lead with the killer reason — *works on dating profiles, where the
   keyboard can't open.*
4. **Steer step:** removed from required onboarding; surfaced in-app at Stage 2. It remains
   in the revisitable Settings tutorial (fallback B).

## Copy

- **Mental-model line (onboarding):** "Replr writes your replies — it isn't for typing.
  Use your normal keyboard to type; tap 🌐 to bring up Replr whenever you want a reply."
- **Steer tip (Stage 2):** "Want it your way? Type your gist with your keyboard, switch to
  Replr, and tap Start — I'll shape it into the reply."
- **Back Tap tip (Stage 3):** "Reply without opening the keyboard. A triple-tap captures
  anything on screen — even dating profiles, where the keyboard can't open. Set it up →"

## Components

- **`AppGroupService`** — read-only milestone helpers + per-tip state:
  - `captureCount` → `loadCaptureSessions().count` (already available).
  - `sessionRegenerateCount: Int` — incremented by the keyboard on each Regenerate; reset on
    a new capture. (New App Group key.)
  - `tipDismissed(_:)` / `tipShowCount(_:)` for tips `steer`, `backTap` (new keys). Retire a
    tip after dismissal or N shows.
- **`KeyboardTipCoordinator`** (new, small) — pure function: given milestones + per-tip state,
  returns the single tip to show now (`.none | .steer | .backTap`), enforcing order
  (steer before Back Tap) and one-at-a-time. Lives in the keyboard target.
- **`IdlePanelView`** — replace the `intentTipShowCount < 3` gate with the coordinator.
  Render the steer coachmark (reworded) or the new Back Tap banner per the coordinator.
- **Regenerate path** (`KeyboardModel` / RepliesPanel) — increment `sessionRegenerateCount`.
- **Onboarding (`OnboardingView`)** — drop the steer step from the required flow; ensure the
  mental-model line is present on the switch/capture step. Keep steer in the revisitable tutorial.
- **Capture path** — confirm `sessionRegenerateCount` resets when a new `CaptureSession` is appended.

## Out of scope / future

- Detecting "user is on a dating profile" to trigger Back Tap contextually (no reliable signal).
- A/B testing thresholds. Numbers (2, 5, 2) are first-pass; tune from feedback.
- Re-recording onboarding Lottie animations.

## Testing

- Coordinator is a pure function → unit-testable: assert the right tip for each
  (captureCount, regenerateCount, dismissal) combination, and that only one shows.
- Build gate (iPhone 17 sim) for the SwiftUI wiring; verify light + dark.
