# Onboarding Redesign — Design Spec

## Goal

Replace the plain system-style onboarding with a dark atmospheric design that matches the keyboard's warm dark palette. No splash/marketing screen — go straight into setup. 5 steps, same sequence as today.

---

## Visual Language

| Token | Value | Usage |
|---|---|---|
| Screen bg | `linear-gradient(170deg, #1E1608, #0F0C05)` | Every screen background |
| Border | `#2E2518` | Screen card edge |
| Icon glow | `radial-gradient(#D4A01728, transparent 70%)` | Behind each icon, 80×80pt |
| Icon stroke | `#D4A017` (mustard) | All SVG outlines |
| Icon fill accent | `#D4A01770` | Subtle inner fill on icons |
| Headline | `#EDE5D0` (cream) | Primary title text |
| Body / subtext | `#6B6050` (taupe) | Descriptions and instructions |
| Step label | `#6B6050`, uppercase, 1pt tracking | "STEP N OF 5" |
| CTA — ghost | border `#D4A01755`, text `#D4A017` | Steps 1–4 |
| CTA — solid | bg `#D4A017`, text `#0F0C05` | Step 5 only (reward) |
| Progress dot active | `#D4A017` | Current step |
| Progress dot inactive | `#2E2518` | Other steps |

**Typography:** SF Pro (system font). Headline 20pt bold, subtext 12pt, step label 10pt uppercase. No custom fonts.

---

## Layout (per screen)

```
┌─────────────────────────┐
│  STEP N OF 5            │  ← 10pt uppercase taupe, top
│                         │
│     [amber glow]        │
│       [SVG icon]        │  ← 48×48pt outlined SVG, centered
│                         │
│     Headline text       │  ← 20pt bold cream, 2 lines max
│    subtext / steps      │  ← 12pt taupe
│                         │
│  [ ── CTA button ── ]   │  ← ghost or solid
│  · · ● · ·             │  ← 5 progress dots
└─────────────────────────┘
```

Full-screen background gradient. No navigation bar. No back button — linear forward-only flow.

---

## Screens

### Screen 1 — Add Keyboard

**Step label:** STEP 1 OF 5  
**Icon:** Keyboard outline SVG — rounded rect with small key squares inside  
**Headline:** "Add the Replr keyboard"  
**Body:** "Settings → General → Keyboards → Add New"  
**CTA:** "Open Settings →" (ghost) — taps open `UIApplication.openSettingsURLString`, then advances to step 2  

### Screen 2 — Full Access

**Step label:** STEP 2 OF 5  
**Icon:** Padlock outline SVG — shackle + body + small filled circle (keyhole)  
**Headline:** "Enable Full Access"  
**Body:** "Lets the keyboard connect to AI."  
**CTA:** "Done →" (ghost) — advances to step 3 (no system prompt; user has already opened Settings from step 1)

### Screen 3 — Photos

**Step label:** STEP 3 OF 5  
**Icon:** Paper airplane SVG — body triangle + fold crease line (matches keyboard's EmailIcon)  
**Headline:** "Allow photos"  
**Body:** "Replr reads your latest screenshot. Nothing is stored."  
**CTA:** "Allow Photos →" (ghost) — triggers `PHPhotoLibrary.requestAuthorization`. On `.authorized`/`.limited`, auto-advances after 0.5s. On `.denied`, CTA becomes "Open Settings →". Skip link below for denied/restricted.

### Screen 4 — Back Tap

**Step label:** STEP 4 OF 5  
**Icon:** Bullseye SVG — three concentric circles with small filled centre (matches keyboard's IntentIcon)  
**Headline:** "Set up double tap"  
**Body (two lines):**
- ① Add the Replr shortcut
- ② Accessibility → Touch → Back Tap → **Double Tap**

**CTA:** "Open Settings →" (ghost) — opens `UIApplication.openSettingsURLString`  
**Secondary link:** "Add Shortcut" — opens the iCloud shortcut URL (`https://www.icloud.com/shortcuts/4239b04c8d0d469b905ce6118c5ce706`)  
**Advance:** Separate "Done →" ghost link below CTA (user self-reports completion)

### Screen 5 — Done

**Step label:** READY (not numbered)  
**Icon:** Bullseye with 3 rings + solid centre dot, larger (56×56pt), outer rings at 0.3 and 0.6 opacity — glow radius increased to 120pt  
**Headline:** "You're in."  
**Body:** "Double-tap the back of your phone while in any chat. Switch to Replr. Pick a reply."  
**CTA:** "Start Replr" — **solid mustard** (first and only filled button) — calls `onComplete()`

---

## Icons (SVG paths, all stroke-based)

All icons: 48×48pt viewBox, `#D4A017` stroke, `stroke-width: 1.3–1.5`, `stroke-linecap: round`.

| Screen | Icon description |
|---|---|
| Add Keyboard | `rect(6,14,36,20,r4)` body + 7 small key `rect` fills at opacity 0.5 |
| Full Access | `rect(13,22,22,16,r3)` lock body + `path` shackle arc + `circle(24,30,r2.5)` keyhole fill |
| Photos | Paper airplane: `M40,8 L8,22 L21,25.5 L24,40 Z` + fold crease `M21,25.5 L27,23` |
| Back Tap | Three concentric circles: r18, r11, r4 (filled at 0.7 opacity) |
| Done | Four rings: r24 (0.3 opacity), r17 (0.6), r9 (full), centre dot r3.5 filled |

---

## Architecture

**Single file:** `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Replace the entire file. Keep:
- `@AppStorage("onboardingStep") private var step = 0` — same state key
- `PhotosPermissionStep` logic — same `PHPhotoLibrary` flow, new visual wrapper
- `BackTapSetupStep` logic — same two sub-steps (add shortcut + settings), new visual wrapper
- `OnboardingStep` generic component — redesigned
- `BackTapSetupFullView` — update copy from "triple-tap" → "double tap" throughout
- `SetupRow` — can be kept or inlined

New shared component: `DarkOnboardingScreen` — a `View` that wraps the common screen chrome (gradient bg, border, amber glow, progress dots) and accepts `stepNumber`, `totalSteps`, `icon`, `headline`, `body`, and `cta` slot as `@ViewBuilder` parameters.

---

## What Does NOT Change

- `@AppStorage("onboardingComplete")` key and gate in `ReplrApp`
- Step count (5 steps)
- iCloud shortcut URL
- `UIApplication.openSettingsURLString` usage
- `PHPhotoLibrary.requestAuthorization` flow
- `onComplete` callback signature

---

## Copy Changes

| Location | Before | After |
|---|---|---|
| Screen 4 headline | "Two quick steps" | "Set up double tap" |
| Screen 4 body step 2 | "Triple Tap → Shortcuts → Replr" | "Back Tap → Double Tap → Replr" |
| Screen 5 body | "Triple-tap the back of your phone" | "Double-tap the back of your phone" |
| `BackTapSetupFullView` title | "Set up BackTap" | "Set up Back Tap" |
| `BackTapSetupFullView` body | "Triple-tapping" | "Double-tapping" |
| `BackTapSetupFullView` step 2 | "Tap 'Triple Tap'" | "Tap 'Double Tap'" |
| `AppShortcutsProvider` / intent phrases | any "triple-tap" phrasing | "double tap" |
