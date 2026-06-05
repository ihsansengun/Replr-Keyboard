# Intent mode — discoverability — design

**Status:** spec for review · **Date:** 2026-06-05 · **Approach:** teach the existing flow (no mechanism rebuild)

## Problem
"Intent mode" lets the user steer the reply: whatever they've **typed in the chat's compose box** before tapping Start becomes the **reply direction** (the LLM builds replies around it). It's powerful but **invisible** — nothing tells users it exists, so they tap Start with an empty box and get generic replies.

It's also inherently multi-step and cross-keyboard: **type with the normal keyboard → switch to Replr → Start.** Replr's keyboard is *generate-only* (no keys, no mic), and a keyboard extension **cannot summon another keyboard** or **draw outside its own frame** — so there's no cheap way to let users type a direction *inside* Replr. We therefore **teach the existing flow** rather than rebuild it.

## Decision
Two complementary, low-cost pieces:

1. **Tutorial step (the upfront teach).** Add an optional step to the usage-tutorial carousel (shown after setup, revisitable from Settings → "How to use Replr").
2. **One-time in-keyboard coachmark (in-the-moment reinforce).** A dismissable balloon in the keyboard idle card the first few opens, then gone.

**Out of scope (rejected this pass):** an in-Replr typed input (would mean building a full keyboard inside the keyboard); voice intent; a native keyboard appearing over Replr (impossible on iOS). The relationship feature is separate/parked.

## Part 1 — Tutorial step "Steer the reply"
- A new step in `UsageTutorialView` (`OnboardingView.swift`), styled like the existing 5 (switch / pick / minimise / screenshot / send).
- Framed **"Optional"** (a power-tip, last in the sequence), title **"Steer the reply"**, three beats:
  1. **Type your angle first** — e.g. "ask her to dinner" or "let her down gently."
  2. **Switch to Replr** and tap Start.
  3. Your replies come back **built around it.**
- **Visual = a Lottie**, for consistency with the other 5 steps — authored in the **same pipeline** (hand-authored/Creator JSON, embedded as a raw-string constant, runtime-tinted to the rose accent like the rest). **Placeholder-grade for now**, polished in the same future pass that redoes all the tutorial animations (the existing 5 are lo-fi placeholders too).
- The carousel's dot count + Next/Done flow extend to include the new step.

## Part 2 — One-time in-keyboard coachmark
- In the chat idle card (`IdlePanelView`), a small **rose balloon** above the **Start** button: *"💡 Want to steer it? Type what you want to say first, then tap Start."* with a **✕** to dismiss, and a subtle dim behind it.
- It points at **Start** (the only element Replr can draw near — it cannot reach the host's compose box); the copy carries the "type first" instruction.
- **Lifecycle:** shown on the idle card until the user dismisses it (✕) **or** after it's appeared on a few separate keyboard sessions, whichever comes first — then never again. Tracked by a small App-Group flag/counter.
- Lives entirely within the keyboard's frame; temporary, so no permanent clutter.

## Implementation touchpoints
| Area | File | Change |
|---|---|---|
| Tutorial step | `Replr/Replr/Features/Onboarding/OnboardingView.swift` | add a 6th `TutStep` + a new embedded `tutSteerJSON` Lottie (placeholder), extend the dots/flow |
| Coachmark UI | `ReplrKeyboard/Views/IdlePanelView.swift` | one-time balloon overlay above Start, ✕ dismiss, dim |
| Coachmark state | `Shared/Constants.swift` + `Shared/AppGroupService.swift` | a key + accessor (e.g. `intentCoachmarkSeen` counter / dismissed flag) |
| New Lottie | embedded raw string (keyboard target can't bundle resources) | placeholder "type → switch → reply" scene, runtime-tinted rose |

## Testing
- iOS build green (app + keyboard share `Shared/`).
- Tutorial shows the new "Steer the reply" step; the dots/Next/Done include it; it's reachable from Settings → How to use Replr.
- Coachmark: appears on the idle card for a new user, dismisses on ✕, **does not reappear** after dismiss or after the appearance cap, and the dismissal **persists across relaunch** (App Group).
- Reduce-Motion: the tutorial Lottie has a static fallback like the others.

## Success criteria
- A new user **encounters the intent teaching** (tutorial step) and is reminded in-context (coachmark) at least once.
- The coachmark is **non-permanent** (respects the "no keyboard clutter" constraint).
- Both are **revisitable / consistent** with existing patterns; no mechanism change to how intent actually works.

## Out of scope
In-Replr typed input · voice intent · polished/final tutorial animations (a separate redo of all of them) · the relationship-dynamic feature (parked).
