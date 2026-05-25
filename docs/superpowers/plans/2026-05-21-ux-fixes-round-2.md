# UX Fixes Round 2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix gesture wording, icon, step count, layout, button hierarchy, and three keyboard loose ends across Replr's onboarding and keyboard extension.

**Architecture:** View-layer and copy changes only — no state machine, networking, or data model changes. All onboarding changes are in `OnboardingView.swift`; all keyboard idle changes are in `KeyboardView.swift` and `IdlePanelView.swift`.

**Tech Stack:** SwiftUI, existing `KBColors` and `OBColors` tokens, SF Symbols.

---

## Affected Files

| File | Fixes |
|------|-------|
| `Replr/Replr/Features/Onboarding/OnboardingView.swift` | 1b, 1c, 1d, 2, 3 |
| `ReplrKeyboard/Views/KeyboardView.swift` | 1a, 4a |
| `ReplrKeyboard/Views/IdlePanelView.swift` | 1a, 2, 4b, 4c |

---

## Fix 1 — Critical bugs

### Task 1a — Kill "triple-tap" wording

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift:198`
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift:46`

**String changes:**

| File | Old | New |
|------|-----|-----|
| `KeyboardView.swift:198` | `"Triple-tap the back of your phone"` | `"Double-tap the back of your phone"` |
| `IdlePanelView.swift:46` | `"triple-tap to screenshot"` | `"double-tap to screenshot"` |

- [ ] Edit `KeyboardView.swift:198`
- [ ] Edit `IdlePanelView.swift:46`
- [ ] Verify: `grep -rni "triple" Replr/ ReplrKeyboard/` returns zero hits
- [ ] Commit: `fix: unify Back Tap gesture wording to double-tap`

---

### Task 1b — Fix "Allow photos" icon

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift:339`

**Change:** Replace `PaperPlaneIcon()` with a photo SF Symbol inside `PhotosPermissionStep`.

```swift
// Replace custom PaperPlaneIcon() with:
Image(systemName: "photo.on.rectangle")
    .font(.system(size: 36, weight: .light))
    .foregroundColor(OBColors.accent)
```

- [ ] Edit `OnboardingView.swift` — swap icon in `PhotosPermissionStep`
- [ ] Commit: `fix: use photo SF symbol on Allow Photos onboarding step`

---

### Task 1c — Fix step count inconsistency (5 → 6 steps)

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

**Root cause:** `BackTapSetupStep` renders two sub-screens (subStep 0 = install shortcut, subStep 1 = configure Settings) but both label themselves "STEP 4 OF 5". Fix by treating them as steps 4 and 5, renaming everything to `N OF 6`, and making `BackTapSetupStep` drive `stepLabel` and `currentStep` from `subStep`.

**Changes:**
1. `DarkOnboardingScreen`: `private let totalSteps = 5` → `6`
2. `AddKeyboardStep`: `"STEP 1 OF 5"` → `"STEP 1 OF 6"`
3. `FullAccessStep`: `"STEP 2 OF 5"` → `"STEP 2 OF 6"`
4. `PhotosPermissionStep`: `"STEP 3 OF 5"` → `"STEP 3 OF 6"`
5. `BackTapSetupStep`: derive stepLabel and currentStep from `subStep`:
   - subStep == 0 → `"STEP 4 OF 6"`, currentStep: 4
   - subStep == 1 → `"STEP 5 OF 6"`, currentStep: 5
6. `DoneStep`: `currentStep: 5` → `currentStep: 6` (already shows "READY"; dots now show 6 dots with last lit)

```swift
// BackTapSetupStep — replace hardcoded values:
DarkOnboardingScreen(
    stepLabel: subStep == 0 ? "STEP 4 OF 6" : "STEP 5 OF 6",
    currentStep: subStep == 0 ? 4 : 5,
    ...
)
```

- [ ] Edit `DarkOnboardingScreen.totalSteps`
- [ ] Edit all four step-label strings in `AddKeyboardStep`, `FullAccessStep`, `PhotosPermissionStep`
- [ ] Edit `BackTapSetupStep` to use dynamic `stepLabel` and `currentStep`
- [ ] Edit `DoneStep.currentStep` from 5 to 6
- [ ] Commit: `fix: honest step count — 6 steps, no duplicate STEP 4 label`

---

### Task 1d — Full Access step: add "Open Settings" primary

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift` — `FullAccessStep`

**Change:** Replace the lone `GhostCTAButton("Done →")` with a two-action layout:
- Primary: "Open Settings →" opens `UIApplication.openSettingsURLString`
- Secondary: plain text link "Done →" that advances

```swift
cta: {
    VStack(spacing: 10) {
        GhostCTAButton(label: "Open Settings →") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        Button("Done →", action: onNext)
            .font(.system(size: 13))
            .foregroundColor(OBColors.taupe)
            .buttonStyle(.plain)
    }
}
```

- [ ] Edit `FullAccessStep` CTA
- [ ] Commit: `fix: Full Access step gains Open Settings primary action`

---

## Fix 2 — Vertical layout (kill the void)

### Task 2 — Centre onboarding content between header and dots

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift` — `DarkOnboardingScreen.body`
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift` — `chatContent`, `emailContent`

**Problem in `DarkOnboardingScreen`:** There is a `Spacer().frame(maxHeight: 80)` between the header and icon, then an unlimited `Spacer()` between the description and the CTA. This pins content up top with empty space below the description.

**Fix — restructure `DarkOnboardingScreen.body`:**

```swift
var body: some View {
    VStack(spacing: 0) {
        // Fixed top: step label + back chevron
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(OBColors.taupe)
                }
                .buttonStyle(.plain)
                .frame(width: 28)
            } else {
                Color.clear.frame(width: 28)
            }
            Spacer()
            Text(stepLabel)
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundColor(
                    currentStep == totalSteps
                        ? OBColors.accent.opacity(0.56)
                        : OBColors.taupe
                )
            Spacer()
            Color.clear.frame(width: 28)
        }
        .padding(.top, 72)
        .padding(.horizontal, 24)

        Spacer()  // flexible — pushes content group to centre

        // Centred content group
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(
                    colors: [OBColors.accent.opacity(currentStep == totalSteps ? 0.22 : 0.16), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: glowSize / 2
                )
                .frame(width: glowSize, height: glowSize)
                icon()
            }
            .padding(.bottom, 32)

            Text(headline)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(OBColors.cream)
                .multilineTextAlignment(.center)
                .tracking(-0.3)
                .padding(.horizontal, 40)

            Text(bodyText)
                .font(.system(size: 13))
                .foregroundColor(OBColors.taupe)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 12)
                .padding(.horizontal, 40)

            // CTA inside the centred group
            VStack(spacing: 16) {
                cta()
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
        }

        Spacer()  // flexible — balances above

        // Fixed bottom: progress dots
        HStack(spacing: 7) {
            ForEach(1...totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == currentStep ? OBColors.accent : OBColors.dotOff)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 56)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [OBColors.bg0, OBColors.bg1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    )
}
```

**Fix — keyboard idle views:** Add `.frame(maxHeight: .infinity)` to both `chatContent` and `emailContent` VStacks so the equal Spacers fill the remaining height correctly.

- [ ] Rewrite `DarkOnboardingScreen.body` with the centred layout above
- [ ] Add `.frame(maxHeight: .infinity)` to `chatContent` and `emailContent` in `IdlePanelView`
- [ ] Commit: `fix: vertically centre onboarding and keyboard-idle content`

---

## Fix 3 — Onboarding button hierarchy

### Task 3 — Filled-amber primary, text-link secondary on every onboarding screen

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

**Rule:** Primary action → `SolidCTAButton`. Secondary action → plain text `Button` (`.foregroundColor(OBColors.taupe)`). Remove `GhostCTAButton` from primary slots.

**Screen-by-screen changes:**

| Screen | Primary (→ SolidCTAButton) | Secondary (text link) |
|--------|----------------------------|-----------------------|
| `AddKeyboardStep` | "Open Settings →" | — |
| `FullAccessStep` | "Open Settings →" | "Done →" |
| `PhotosPermissionStep` — `.authorized`/`.limited` | "Continue →" | — |
| `PhotosPermissionStep` — `.denied`/`.restricted` | "Open Settings →" | "Skip" |
| `PhotosPermissionStep` — default | "Allow Photos →" | — |
| `BackTapSetupStep` subStep 0 | "Add Shortcut →" | "Done — next step" |
| `BackTapSetupStep` subStep 1 | "Open Settings →" | "Done →" |
| `DoneStep` | "Start Replr" (already `SolidCTAButton`) | — |

**Notes:**
- `GhostCTAButton` will only remain if a screen genuinely has no primary action (currently none after this fix).
- The `DoneStep` already uses `SolidCTAButton` — no change needed.

- [ ] Change `AddKeyboardStep` CTA from `GhostCTAButton` → `SolidCTAButton`
- [ ] Change `FullAccessStep` "Open Settings →" from `GhostCTAButton` → `SolidCTAButton`
- [ ] Change `PhotosPermissionStep` all three branches — primary → `SolidCTAButton`, secondary → text link
- [ ] Change `BackTapSetupStep` both sub-steps — "Add Shortcut →" / "Open Settings →" → `SolidCTAButton`
- [ ] Commit: `fix: onboarding — filled-amber primary, text-link secondary on every screen`

---

## Fix 4 — Keyboard loose ends

### Task 4a — Tone row trailing fade + scroll padding

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `ToneRow`

**Current mask:** fades from opaque to clear between 0.85 and 1.0 (only 15% fade zone). Chips content has `.padding(.horizontal, 8)` — no trailing room.

**Fix:**
1. Extend fade zone: start fade at `0.72` instead of `0.85`
2. Add trailing content padding so last chip can fully scroll into view: change inner HStack padding to `.padding(.leading, 8).padding(.trailing, 32)`

```swift
.mask(
    LinearGradient(
        stops: [
            .init(color: .black, location: 0.0),
            .init(color: .black, location: 0.72),
            .init(color: .clear, location: 1.0),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
)
```

```swift
// Inner HStack padding change:
.padding(.leading, 8)
.padding(.trailing, 32)
```

- [ ] Edit `ToneRow` mask stops
- [ ] Edit tone chip HStack padding
- [ ] Commit: `fix: tone row — stronger trailing fade, trailing scroll padding`

---

### Task 4b — Disabled email button label legibility

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift` — `emailContent`

**Current:** `.opacity(hasClipboardText ? 1.0 : 0.45)` applied to the entire button, dimming both background and text label.

**Fix:** Move opacity/disabled styling so only the background dims; text stays at full opacity.

```swift
Button { model.generateEmailReply() } label: {
    HStack(spacing: 8) {
        Image(systemName: "doc.on.clipboard.fill")
            .font(.system(size: 14))
        Text("Generate from clipboard")
            .font(.system(size: 14, weight: .semibold))
    }
    .foregroundColor(hasClipboardText ? KBColors.accentFg : KBColors.textDim)
    .frame(maxWidth: .infinity)
    .frame(height: 46)
    .background(KBColors.accent.opacity(hasClipboardText ? 1.0 : 0.30))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
}
.buttonStyle(.plain)
.padding(.horizontal, 16)
.disabled(!hasClipboardText)
```

- [ ] Edit `emailContent` button styling
- [ ] Commit: `fix: disabled email button — dim fill, keep label legible`

---

### Task 4c — Email idle: merge duplicate status lines

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift` — `emailContent`

**Current:** Two helpers below the button:
1. `"Copy the email you're replying to, then tap above"` (always)
2. Conditional checkmark + `"Nothing copied yet"` / `"Email text ready"`

**Fix:** Remove line 1 entirely; update line 2 to carry the full message:

```swift
HStack(spacing: 4) {
    if hasClipboardText {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 11))
            .foregroundColor(.green)
    }
    Text(hasClipboardText ? "Email ready — tap to generate" : "Copy an email, then tap to generate")
        .font(.system(size: 11))
        .foregroundColor(hasClipboardText ? .green : KBColors.textDim)
}
.padding(.top, 10)
.animation(.easeInOut(duration: 0.2), value: hasClipboardText)
```

- [ ] Edit `emailContent` — remove static helper line, update status line copy
- [ ] Commit: `fix: email idle — single dynamic status line`

---

## Execution order

Fixes 1 → 2 → 3 → 4. Within Fix 1, tasks are independent except 1d depends on 1c (step numbering should be correct before adding the new button). Fix 3 builds on Fix 1d (the Open Settings button already exists before we change its style). Fix 2 is pure layout and can be applied before or after Fix 1/3.

## Definition of Done

- [ ] No "triple" anywhere: `grep -rni triple Replr/ ReplrKeyboard/` = 0 hits
- [ ] `PhotosPermissionStep` icon is a photo SF Symbol
- [ ] Step indicator: 6 sequential labels (1-6), 6 dots, no duplicate labels
- [ ] `FullAccessStep` has "Open Settings →" primary action
- [ ] All onboarding screens: filled-amber primary, text-link secondary
- [ ] No large empty band on any onboarding screen or keyboard idle view
- [ ] Tone row last chip fully scrollable with visible trailing fade
- [ ] Disabled email button label is legible
- [ ] Email idle shows exactly one status line
- [ ] Both `Replr` and `ReplrKeyboard` schemes build with no new warnings
