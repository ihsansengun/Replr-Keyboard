# Claude Code prompt — Replr UI animations

Paste everything below the line into Claude Code, run from the repo root.

---

Add three native SwiftUI animations to the Replr app. This is a motion-only task — do not change any logic, networking, or state-machine behavior, only add view-layer animation around what already exists.

## Before you start

Read `CLAUDE.md`, then read `ReplrKeyboard/Views/KeyboardView.swift` (the `KeyboardState` enum and `KeyboardModel`), `ReplrKeyboard/KeyboardViewController.swift` (the per-state hardcoded heights), and `ReplrKeyboard/Views/LoadingView.swift`. Then locate where an email reply is generated — search for "email" across the iOS targets and the backend `POST /reply` callers — and tell me in your summary which file and which state drives the email flow before you implement animation #3.

## What to build

1. **Chat window initial load.** When the keyboard transitions into its reply-suggestions state and the reply cards first appear, animate them in: a brief fade plus a small upward slide, with the cards staggered (~40ms apart) so they cascade rather than pop in together. The tone-selector bar and contact chip should settle in with the same curve. The first frame should never flash unstyled.

2. **Minimize and back to top.** Animate the `idle ↔ collapsed` transition (collapse to expose the chat for a screenshot, then restore). The keyboard height itself changes between states — `KeyboardViewController` sets a hardcoded height per state — so the height change and the SwiftUI content change must be animated together and stay in sync; a smooth height interpolation with the content cross-fading is the goal, not a jump. "Back to top" is the restore/expand direction and should feel like a clean reverse of the minimize.

3. **"Generating" loader.** Replace the plain spinner shown while a reply/email is being generated with a lightweight, on-brand looping animation (e.g. a row of pulsing dots or a soft shimmer over skeleton reply cards). It must loop indefinitely and stop cleanly when results arrive. If the email flow lives in the keyboard extension, keep this animation extremely cheap; if it lives in the companion app, it can be slightly richer.

## Constraints

- **Native SwiftUI only.** No Lottie, no Rive, no third-party packages. Use `withAnimation`, `.transition`, `.matchedGeometryEffect`, and `PhaseAnimator` / `KeyframeAnimator` as appropriate.
- **Keyboard extension memory budget is tight (~50–60MB).** Keep all keyboard-side animation allocation-free and asset-free — no images, no large view trees spun up just for motion.
- **Honor Reduce Motion.** Read `@Environment(\.accessibilityReduceMotion)`; when it's on, replace slides/scales with plain cross-fades (or no motion) and never loop large movements.
- **Match the existing visual style.** Use the existing `KBColors` tokens for any color — do not introduce new colors or hardcode hex values.
- **One small set of shared animation constants.** Define the durations/curves once (e.g. a `KBAnimation` enum) and reuse them; don't scatter magic numbers. Keep transitions in the 0.18–0.25s range to match the keyboard's existing feel.
- Don't call async APIs from the keyboard extension — these animations are pure view-layer, so that rule isn't at risk, but keep it in mind.

## Definition of done

- The three animations work and the keyboard builds for the `ReplrKeyboard` scheme with no warnings introduced.
- Reduce Motion is respected for all three.
- No logic, networking, layout values, or state-machine transitions changed — diff should be additive view code plus the shared animation constants.
- In your final summary: list the files touched, the animation constants you added, and confirm which file/state the email loader is wired to.

Work in small steps and show me the diff for each animation before moving to the next.
