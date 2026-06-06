# Onboarding — Wispr-inspired Reimagining

**Status:** Design approved 2026-06-06. Account-free. Built on branch `onboarding-wispr-redesign`.

## Goal

Reimagine Replr's onboarding into a calm, premium, Wispr-grade funnel that delivers the
first "aha" *before* setup ends — without adding accounts or a login.

## Non-goals

- **No accounts / sign-in UI.** Silent-identity credit recovery and the server ledger
  remain in the parked monetization review. This work only avoids *adding* a login.
- Not redesigning the keyboard reply surfaces (idle / results) — separate effort.
- No paywall / pricing changes here.

## Design language (the Phase 1 foundation)

- **Type:** bundle **Fraunces** (OFL) in the companion app for *display headlines only*;
  keep the existing sans for all body / UI / buttons. Expose `ReplrTheme.Font.serif(...)`.
  Honor Dynamic Type.
- **Color restraint:** ink + warm `bg` + whitespace; **amber highlights one word** per
  headline (e.g. *free*, *safe*, *magic*); the rose `brandGradient` is reserved for the
  single primary CTA per screen. Pull gradient back everywhere else.
- **Doodles:** a small set of amber hand-drawn annotations (circle, squiggle-arrow) as
  SwiftUI `Shape`s (or Lottie) for coachmarks.
- **Progress:** a segmented top bar across the *setup* steps (survey + permissions +
  Back Tap); not shown on splash / carousel / ready.
- Verify **light + dark** every screen.

## Flow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 1 | Splash | existing | animated logo |
| 2 | Intro carousel | NEW | 3 serif "show-the-magic" slides (Lottie) |
| 3 | Survey | NEW | seeds starting tone + a light About You hint |
| 4 | Keyboard + Full Access | reskin | priming card + faux-toggle preview + looping video / doodle |
| 5 | Photos | reskin | same priming treatment |
| 6 | Back Tap | NEW (skippable) | doodle / video coachmark; "Set up later" escape |
| 7 | Ready → sample-demo first win | reskin + NEW | pre-baked demo, no network/credits |
| 8 | Usage tutorial | existing | revisitable |

Retain the existing **status-aware skipping** (already-granted permission steps auto-skip)
and `startAtSetup` (a Settings revisit skips the marketing/carousel).

### 2 · Intro carousel

- 3 swipeable slides, page dots, "Get started" / "Next".
- Copy (serif headline, one amber word):
  1. *"Never stare at a blank reply again."* — screenshot any chat, get replies in seconds.
  2. *"Replies in **your** tone."* — tone chips.
  3. *"Works in any chat — even where the keyboard can't open."* — sets up Back Tap.
- Motion: Lottie (existing pipeline) showing screenshot → replies. Static fallback.

### 3 · Personalization survey

- Headline: *"Where do you need better replies?"* — multi-select cards w/ icons:
  Dating · Texting friends · Work / Slack · Family · Email · Something else.
- On Next → `OnboardingSurvey.apply(selection:)` (pure, unit-tested):
  - **Sets the default tone** from the primary pick — intended map (reconcile with the live
    tone list at build time; fall back to Natural): Dating→Flirty · Friends→Casual ·
    Work→Professional · Family→Warm/Natural · Email→Professional · Else→Natural.
  - **Appends a one-line About You hint** (does not overwrite an existing About You), e.g.
    Dating→"Replying on dating apps."
- Skippable; no pick → no changes.

### 4–5 · Permission steps (reskin)

- Reuse `KeyboardSetupStep` + `PhotosPermissionStep` and the existing settings-preview
  mimics (`KeyboardSettingsPreview`, `PhotosSettingsPreview`).
- Add: serif title; a dark **"Your data is safe"** priming card (amber *safe*) with a
  one-line reassurance; the faux-toggle preview; a looping how-to video (screen-recording
  asset) or doodle arrows.
- Keep the existing permission detection + auto-advance behavior.

### 6 · Back Tap (new, skippable)

- New step wrapping the existing `BackTapSetupFullView` content. Framing:
  *"Reply anywhere — even on profiles."* Doodle / video coachmark. A prominent
  **"Set up later"** escape that advances; it stays available in Settings.
- Also fixes the currently-undiscoverable Back Tap (see TODO.md).

### 7 · Ready → sample-demo first win

- Serif celebration → a built-in **sample demo**: a pre-baked canned chat (rendered bubbles
  or a static image) + *"Tap to see Replr work"* → canned replies animate in
  (Lottie / scripted). **No network, no credits, works offline.** Then "Done".

## Components / files

**New — companion app (`Replr/Replr/Features/Onboarding/`):**
- `IntroCarouselStep.swift`, `PersonalizationSurveyStep.swift`,
  `BackTapOnboardingStep.swift`, `SampleDemoStep.swift`
- `OnboardingDoodles.swift` (amber `Shape` annotations), `OnboardingProgressBar.swift`
- `OnboardingSurvey.swift` (pure mapping: selection → tone + About You hint)

**New — theme / assets:**
- Fraunces font files (OFL) + `UIAppFonts` in the **companion** Info.plist;
  `ReplrTheme.Font.serif(size:weight:)` token.
- Full-Access screen recording (and optionally Photos); carousel + demo Lottie JSON;
  canned demo-chat content.

**Modify:**
- `OnboardingView.swift` — step enum/sequence (insert carousel, survey, Back Tap, sample
  demo), progress bar, retain status-aware skipping + `startAtSetup`.
- `KeyboardSetupStep`, `PhotosPermissionStep` — reskin + priming.
- `ReadyStep` — lead into the sample demo.
- `Shared/ReplrTheme.swift` + `DESIGN.md` — serif token + onboarding-language notes.

## Phasing (each phase ships working + is committed)

- **Phase 1 — Foundation + reskin:** Fraunces token, doodle primitives, progress bar;
  reskin existing Welcome / Keyboard / Photos / Ready with serif + priming + restraint.
  No new steps yet. Build + light/dark.
- **Phase 2 — New steps:** intro carousel + survey (`OnboardingSurvey` mapping via TDD),
  wired into the flow.
- **Phase 3 — Back Tap + first win + video:** fold Back Tap in (skippable); sample-demo
  Ready; record + embed the Full-Access video.

## Testing

- **Unit (Swift Testing, `Replr/ReplrTests/`):** `OnboardingSurvey` mapping (each selection
  → tone + hint; multi-select primary pick; About You append-not-overwrite); progress
  computation; status-aware `nextStep`.
- **Manual / device:** full flow from each entry (fresh install, Settings-revisit);
  permission grant / deny / skip paths; light + dark; Dynamic Type.
- **Build gate:** `xcodebuild -project Replr.xcodeproj -scheme Replr -sdk iphonesimulator
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build` per phase.

## Risks / revert

- Isolated on branch `onboarding-wispr-redesign`; per-task commits; revert = abandon branch.
- Fraunces bundle size — use static weights or a subset; companion-only (keyboard ext
  untouched).
- Sample demo is pre-baked → no credit / network risk during onboarding.

## Open (confirm at build time)

- Exact survey→tone names, pending the live tone list.
- Carousel / demo as Lottie vs a lighter pure-SwiftUI animation — decide in build.
- Whether the existing splash/Welcome becomes the carousel's first slide or stays separate.
