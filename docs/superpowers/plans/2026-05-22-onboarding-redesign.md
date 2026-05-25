# Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the centered icon-based onboarding with the v2 left-aligned design — new welcome splash, progress bar, coral section labels, settings navigation cards, shortcut preview card, and back-tap configuration screen.

**Architecture:** Pure view-layer rewrite of `OnboardingView.swift`. The layout wrapper (`DarkOnboardingScreen`) is replaced with a new `OnboardingStep` that handles header, progress bar, and left-aligned text. Each step screen is replaced individually. The 6-step (dot) flow becomes a welcome splash + 5 counted steps. No logic, state machine, or AppGroup changes.

**Tech Stack:** SwiftUI, `@AppStorage` for step persistence, `UIApplication.open` for deep-linking to Settings/Shortcuts, existing `PrimaryButton` / `TertiaryButton` / `ReplrMark` from `Shared/ReplrComponents.swift`.

---

## File Map

| File | Change |
|------|--------|
| `Replr/Replr/Features/Onboarding/OnboardingView.swift` | Full rewrite — new `OnboardingStep` wrapper, new `WelcomeStep`, 5 redesigned step screens, updated coordinator |

All other files are untouched.

---

## Design reference

Screenshots live in `docs/design/screenshots/`. The relevant ones:

| File | Content |
|------|---------|
| `01-onboarding-welcome.png` | Welcome splash — no step counter |
| `02-onboarding-add-keyboard.png` | Step 01/05 — settings nav card |
| `03-onboarding-install-shortcut.png` | Step 04/05 — shortcut preview card |
| `04-onboarding-back-tap.png` | Step 05/05 — accessibility path card |

Steps 02/05 and 03/05 (Full Access, Photos) are not shown but follow the same `OnboardingStep` layout pattern with their existing content.

---

## Task 1: Replace `DarkOnboardingScreen` with `OnboardingStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: `DarkOnboardingScreen` is the current shared layout wrapper (centred, icon-glow, dot progress). Replace it entirely with `OnboardingStep` — left-aligned, progress bar, coral section label, `ReplrMark` header. The new wrapper is used by all 5 counted steps. The Welcome splash has its own layout and does NOT use this wrapper.

- [ ] **Replace the `// MARK: - Shared wrapper` block** (lines 4–103) with the following. Leave everything below line 103 untouched for now — this task only replaces the wrapper.

```swift
// MARK: - Shared step wrapper

private struct OnboardingStep<Content: View, CTA: View>: View {
    let step: Int           // 1-based, 1–5
    let totalSteps: Int     // always 5
    let sectionLabel: String
    let headline: String
    let bodyText: String
    @ViewBuilder var content: () -> Content
    @ViewBuilder var cta: () -> CTA

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: replr• mark + step counter
            HStack(alignment: .center) {
                ReplrMark(size: 14)
                Spacer()
                Text(String(format: "%02d / %02d", step, totalSteps))
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(ReplrTheme.Color.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Segmented progress bar
            HStack(spacing: 4) {
                ForEach(1...totalSteps, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i <= step ? ReplrTheme.Color.accent : ReplrTheme.Color.border)
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            // Text block
            VStack(alignment: .leading, spacing: 8) {
                Text(sectionLabel)
                    .font(ReplrTheme.Font.overline)
                    .tracking(1.5)
                    .foregroundColor(ReplrTheme.Color.accent)
                Text(headline)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(bodyText)
                    .font(ReplrTheme.Font.callout)
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Variable content
            content()
                .padding(.horizontal, 24)

            Spacer(minLength: 16)

            // CTA area
            VStack(spacing: 12) {
                cta()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
    }
}
```

- [ ] **Build to confirm no compile errors** (existing step structs still use `DarkOnboardingScreen` but that's been removed — they'll fail, which is expected):

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme ReplrKeyboard -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: errors referencing `DarkOnboardingScreen` in the step structs below. That's fine — fixed in Tasks 3–8.

- [ ] **Do NOT commit yet** — this task alone leaves the build broken. Commit after Task 2.

---

## Task 2: Rewrite `WelcomeStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: The welcome splash is a new screen not in the current codebase. It has no step counter or progress bar. It shows the `ReplrMark` wordmark large, a two-line hero heading, body text, an "On-device" privacy badge, and two CTAs. It is shown at `step == 0` in the coordinator.

- [ ] **Remove the entire `// MARK: - Icons (Canvas-drawn, stroke-based)` block** (lines 105–223) — the Canvas icons are no longer used in the new design. Delete from the `// MARK: - Icons` comment through the closing `}` of `BullseyeDoneIcon`.

- [ ] **Replace the `// MARK: - Step views` comment** (was at ~line 225) with the following `WelcomeStep` and keep the comment as a section marker:

```swift
// MARK: - Step views

private struct WelcomeStep: View {
    let onNext: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Nav bar row
                HStack {
                    ReplrMark(size: 14)
                    Spacer()
                    Text("Welcome")
                        .font(ReplrTheme.Font.caption)
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Hero content
                VStack(alignment: .leading, spacing: 16) {
                    ReplrMark(size: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("The reply is")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("already written.")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }

                    Text("Triple-tap the back of your phone. Replr reads the chat, drafts the reply, you tap to send.")
                        .font(ReplrTheme.Font.callout)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .lineSpacing(4)

                    // Badges
                    HStack(spacing: 16) {
                        Label("On-device", systemImage: "lock.shield")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                        Label("4.9 ★", systemImage: "star.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTAs
                VStack(spacing: 12) {
                    PrimaryButton(label: "Set it up →", action: onNext)
                    TertiaryButton(label: "I have an account", action: onSignIn)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
```

- [ ] **Build** — still fails on the remaining step structs that reference `DarkOnboardingScreen`. Expected.

- [ ] **Do NOT commit yet.** Commit after Task 3 when build is green.

---

## Task 3: Rewrite `AddKeyboardStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: Step 1/5. Design shows left-aligned layout with a settings navigation card (breadcrumb path + keyboard row preview). The card sits below the text block. CTA opens Settings; secondary link skips.

- [ ] **Replace the entire `private struct AddKeyboardStep`** block with:

```swift
private struct AddKeyboardStep: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingStep(
            step: 1, totalSteps: 5,
            sectionLabel: "Keyboard",
            headline: "Add Replr to iOS.",
            bodyText: "The keyboard is where the replies show up. iOS will ask you to add it from Settings."
        ) {
            // Settings navigation card
            VStack(alignment: .leading, spacing: 0) {
                // Breadcrumb path
                HStack(spacing: 4) {
                    ForEach(["Settings", "General", "Keyboard", "Keyboards"], id: \.self) { step in
                        if step != "Settings" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Text(step)
                            .font(.system(size: 12))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                // Indented path continuation
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                        Text("Add New")
                            .font(.system(size: 12))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                    .padding(.leading, 14)

                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.accent)
                        Text("Replr")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.accent)
                    }
                    .padding(.leading, 28)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 14)

                Divider()
                    .overlay(ReplrTheme.Color.border)

                // Keyboard preview row
                HStack(spacing: 12) {
                    ReplrMark(size: 13)
                    Text("Replr")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Text("English (US)")
                        .font(.system(size: 12))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.success)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Open Keyboard Settings →") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    onNext()
                }
                TertiaryButton(label: "Already added", action: onNext)
            }
        }
    }
}
```

- [ ] **Build** — still may fail on the remaining step structs. Continue.

---

## Task 4: Rewrite `FullAccessStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: Step 2/5. No design screenshot, but follows the same `OnboardingStep` layout. Replaces the old centered `LockIcon` version with the left-aligned wrapper. Content area is empty (no card needed — just the text block and CTAs).

- [ ] **Replace the entire `private struct FullAccessStep`** block with:

```swift
private struct FullAccessStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 2, totalSteps: 5,
            sectionLabel: "Permissions",
            headline: "Enable Full Access.",
            bodyText: "Lets the keyboard connect to AI. Settings → General → Keyboards → Replr → Full Access."
        ) {
            EmptyView()
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Open Settings →") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Done →", action: onNext)
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }
}
```

- [ ] **Build** — still may fail on remaining step structs.

---

## Task 5: Rewrite `PhotosPermissionStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: Step 3/5. Follows the same `OnboardingStep` layout. The permission request logic is preserved. No content card.

- [ ] **Replace the entire `private struct PhotosPermissionStep`** block with:

```swift
private struct PhotosPermissionStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        OnboardingStep(
            step: 3, totalSteps: 5,
            sectionLabel: "Permissions",
            headline: "Allow Photos.",
            bodyText: "Replr reads your latest screenshot. Nothing is stored or uploaded."
        ) {
            EmptyView()
        } cta: {
            if status == .authorized || status == .limited {
                PrimaryButton(label: "Continue →", action: onNext)
            } else if status == .denied || status == .restricted {
                VStack(spacing: 12) {
                    PrimaryButton(label: "Open Settings →") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    TertiaryButton(label: "Skip", action: onNext)
                }
            } else {
                PrimaryButton(label: "Allow Photos →") {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                        DispatchQueue.main.async {
                            status = newStatus
                            if newStatus == .authorized || newStatus == .limited {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onNext() }
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }
}
```

- [ ] **Build** — still may fail on remaining step structs.

---

## Task 6: Add `InstallShortcutStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: Step 4/5. New screen (previously combined inside `BackTapSetupStep`). Shows a shortcut preview card with 4 labelled actions. CTA deep-links to the iCloud shortcut; secondary marks as done and advances.

- [ ] **Delete the entire `private struct BackTapSetupStep`** block (current combined screen).

- [ ] **In its place, insert these two new structs** (InstallShortcutStep and BackTapStep are added together here; BackTapStep is written in Task 7):

```swift
private struct InstallShortcutStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    private let shortcutURL = "https://www.icloud.com/shortcuts/4239b04c8d0d469b905ce6118c5ce706"

    var body: some View {
        OnboardingStep(
            step: 4, totalSteps: 5,
            sectionLabel: "Shortcut",
            headline: "Install the Shortcut.",
            bodyText: "A small recipe lives in iOS Shortcuts. It takes the screenshot, hands it to Replr, opens the keyboard."
        ) {
            // Shortcut preview card
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                            .frame(width: 32, height: 32)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.onAccent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Replr Capture")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("4 actions")
                            .font(.system(size: 11))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().overlay(ReplrTheme.Color.border)

                // Actions list
                VStack(spacing: 0) {
                    ForEach(Array([
                        "Take Screenshot",
                        "Save to Photos",
                        "Open Replr",
                        "Show Keyboard"
                    ].enumerated()), id: \.offset) { idx, action in
                        HStack {
                            Text(String(format: "%02d", idx + 1))
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                                .frame(width: 24, alignment: .leading)
                            Text(action)
                                .font(.system(size: 13))
                                .foregroundColor(ReplrTheme.Color.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ReplrTheme.Color.success)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if idx < 3 {
                            Divider().overlay(ReplrTheme.Color.border).padding(.leading, 52)
                        }
                    }
                }
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Add to Shortcuts →") {
                    if let url = URL(string: shortcutURL) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Inspect the recipe", action: onNext)
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }
}
```

- [ ] **Build** — still fails until BackTapStep and DoneStep are handled.

---

## Task 7: Rewrite `BackTapStep`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: Step 5/5. Replaces the old `BackTapSetupStep`. Shows an accessibility navigation card (breadcrumb + highlighted action row). Two CTAs: open Settings (primary) and "Use double-tap instead" (tertiary). A "Done →" button completes onboarding.

- [ ] **Delete `private struct DoneStep`** entirely (the centered "You're in." screen — removed in v2).

- [ ] **Insert `BackTapStep` immediately after `InstallShortcutStep`:**

```swift
private struct BackTapStep: View {
    let onNext: () -> Void     // completes onboarding
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 5, totalSteps: 5,
            sectionLabel: "Back Tap",
            headline: "Triple-tap = capture.",
            bodyText: "iOS Back Tap turns a tap on the back of the phone into a Shortcut. Wire triple-tap to Replr Capture."
        ) {
            // Accessibility navigation card
            VStack(alignment: .leading, spacing: 0) {
                // Breadcrumb path
                HStack(spacing: 4) {
                    ForEach(["Accessibility", "Touch", "Back Tap", "Triple Tap"], id: \.self) { step in
                        if step != "Accessibility" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        let isLast = step == "Triple Tap"
                        Text(step)
                            .font(.system(size: 12, weight: isLast ? .semibold : .regular))
                            .foregroundColor(isLast ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().overlay(ReplrTheme.Color.border)

                // Shortcut action row
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ReplrTheme.Color.accent)
                            .frame(width: 32, height: 32)
                        Image(systemName: "scope")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.onAccent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replr Capture")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("Three taps. The apple, the back, anywhere.")
                            .font(.system(size: 11))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Open Back Tap Settings →") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Use double-tap instead", action: onNext)
                TertiaryButton(label: "Done →", action: onNext)
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }
}
```

- [ ] **Build** — should now succeed (all step structs use the new layout).

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme ReplrKeyboard -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

---

## Task 8: Update `OnboardingView` coordinator + `BackTapSetupFullView`

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: The coordinator drives the 6-screen flow (step 0 = Welcome, steps 1–5 = counted steps). `BackTapSetupFullView` (the deep-link sheet from `replr://setup`) also gets a v2 polish pass. `SetupRow` helper is removed — `BackTapSetupFullView` gets a simpler numbered list.

- [ ] **Replace `struct OnboardingView`** (the root coordinator) with:

```swift
struct OnboardingView: View {
    var onComplete: () -> Void
    var onSignIn: () -> Void = {}
    @AppStorage("onboardingStep") private var step = 0

    var body: some View {
        switch step {
        case 0:
            WelcomeStep(onNext: { step = 1 }, onSignIn: onSignIn)
        case 1:
            AddKeyboardStep(onNext: { step = 2 })
        case 2:
            FullAccessStep(onNext: { step = 3 }, onBack: { step = 1 })
        case 3:
            PhotosPermissionStep(onNext: { step = 4 }, onBack: { step = 2 })
        case 4:
            InstallShortcutStep(onNext: { step = 5 }, onBack: { step = 3 })
        case 5:
            BackTapStep(onNext: { step = 0; onComplete() }, onBack: { step = 4 })
        default:
            WelcomeStep(onNext: { step = 1 }, onSignIn: onSignIn)
        }
    }
}
```

- [ ] **Delete `private struct SetupRow`** (lines ~403–419 in the original file — no longer used).

- [ ] **Replace `struct BackTapSetupFullView`** with a v2-styled version:

```swift
struct BackTapSetupFullView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Back Tap")
                            .font(ReplrTheme.Font.overline)
                            .tracking(1.5)
                            .foregroundColor(ReplrTheme.Color.accent)
                        Text("Triple-tap = capture.")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.3)
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("Triple-tapping the back of your iPhone triggers Replr to capture a screenshot and generate replies.")
                            .font(ReplrTheme.Font.callout)
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array([
                            "Settings → Accessibility → Touch → Back Tap",
                            "Tap \"Triple Tap\"",
                            "Scroll down and choose Shortcuts → Replr Capture"
                        ].enumerated()), id: \.offset) { idx, text in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundColor(ReplrTheme.Color.onAccent)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(ReplrTheme.Color.accent))
                                Text(text)
                                    .font(ReplrTheme.Font.callout)
                                    .foregroundColor(ReplrTheme.Color.textPrimary)
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(16)
                    .background(ReplrTheme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .stroke(ReplrTheme.Color.border, lineWidth: 1)
                    )

                    Text("First time you triple-tap, iOS will ask to share the screenshot with Replr. Tap \"Allow Always\".")
                        .font(ReplrTheme.Font.footnote)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .lineSpacing(3)

                    PrimaryButton(label: "Open Settings →") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .navigationTitle("Set up Back Tap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(ReplrTheme.Color.accent)
                }
            }
        }
    }
}
```

- [ ] **Build — must succeed with zero errors:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme ReplrKeyboard -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Commit:**

```bash
git add Replr/Replr/Features/Onboarding/OnboardingView.swift
git commit -m "$(cat <<'EOF'
feat: onboarding v2 — welcome splash, left-aligned steps, progress bar, nav cards, shortcut preview

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Verification checklist

After all tasks complete, manually review or build+run in simulator:

- [ ] Welcome screen: `replr•` wordmark large, "The reply is / already written." heading, body text, "On-device" badge, "Set it up →" button
- [ ] Steps 1–5: each shows `replr•` header + "01 / 05" counter + filled progress bar segments + coral section label + bold heading
- [ ] Step 1 (Add Keyboard): settings navigation card with indented path, keyboard preview row
- [ ] Step 4 (Install Shortcut): shortcut card with 4 actions + checkmarks
- [ ] Step 5 (Back Tap): accessibility breadcrumb + Replr Capture row
- [ ] Back button: visible on steps 2–5, navigates back correctly
- [ ] `BackTapSetupFullView` (open via `replr://setup` deep link): v2 dark theme, numbered steps, triple-tap copy
- [ ] No "double-tap" references anywhere in the onboarding UI
