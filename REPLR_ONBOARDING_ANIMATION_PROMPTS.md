# Replr — onboarding animation prompts

For a prompt-to-Lottie tool (LottieFiles Creator → AI prompt; also works in LottieGen / vizGPT). Six looping guidance animations, one per onboarding step.

How to use: paste the **Shared style** block, then one **step prompt**, into the AI prompt field. Generate, refine if needed, recolor to pure white, export as Lottie JSON. Keep each file small (simple shapes, short loop).

Scope note: this pack is the **onboarding** animations only. The in-keyboard guidance animations (capture-bar tap glyph, loading dots, hints) must be native SwiftUI — the keyboard is a memory-limited extension and can't carry the Lottie runtime. Those go through a Claude Code build, not this pack.

---

## Shared style — prepend to every prompt

Minimalist looping UI animation for a premium app. Single flat color: pure white (#FFFFFF) on a fully transparent background — designed to be recolored in-app. Clean geometric line art, even consistent stroke weight, sharp controlled corners. No color, no gradient, no shadow, no 3D, no glow, no text. Motion is smooth, subtle and restrained — confident, not playful. Seamless loop, roughly 2.5 seconds, with a calm hold at the start of each cycle.

---

## Step 1 — Add the keyboard

A geometric outline of a phone keyboard. Its rows of keys draw in quickly from left to right with a slight stagger, the keyboard settles, then a single key gives one soft pulse of emphasis before the loop resets. Crisp, mechanical-but-smooth.

## Step 2 — Enable Full Access

A simple geometric padlock, centered. The loop: the lock sits closed, then the curved shackle lifts and rotates open with a confident ease, holds open for a beat, then closes again. One clean unlock motion, no bounce.

## Step 3 — Allow photos

A geometric outline of a photo / screenshot frame with a small mountain-and-sun glyph inside. A thin horizontal scan line sweeps down over the frame once — as if the image is being read — then a tiny spark blinks at the top corner. Calm, intelligent, precise.

## Step 4 — Install the shortcut

A rounded-square tile, like a shortcut card. The loop: the tile draws its outline, then a small glyph snaps into its center with a brief scale-down settle, and a thin checkmark strokes in beside it. Assembly that feels deliberate and finished.

## Step 5 — Set up double-tap (Back Tap)

The flat back of a phone, geometric outline, centered. The loop: two quick taps land at the center — and with each tap, concentric ripple rings expand outward and fade. After the second ripple, a short hold, then reset. This is the key gesture; make the double-tap rhythm unmistakable.

## Step 6 — You're in (ready)

The Replr reply-arrow mark draws itself with a single confident stroke — arrowhead first, then the shaft hooking down — then settles with one subtle pulse. A quiet, premium "done" moment. This one may play once and hold rather than loop, if the tool allows.

---

## Export & use notes

- Recolor to pure white before export; the app tints it (white on dark, near-black on light).
- Transparent background — confirm there's no white or black artboard baked in.
- Keep loops 2–3s and shapes simple so the JSON stays small.
- Motion should read as ~100–300ms beats — fast and purposeful. If an animation feels decorative or attention-grabbing, simplify it; guidance motion should inform, not perform.
- Use these in the **companion app onboarding only**. Lottie runtime is fine there; never in the keyboard extension.
