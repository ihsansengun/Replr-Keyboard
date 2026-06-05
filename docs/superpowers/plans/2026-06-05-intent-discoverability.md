# Intent-mode Discoverability — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the hidden "Intent mode" (type a direction before Start) by teaching it — a 6th optional "Steer the reply" tutorial step + a one-time, dismissable in-keyboard coachmark.

**Architecture:** Pure iOS, additive, follows existing patterns. The tutorial carousel auto-derives its count/dots/Next-Done from `steps.count`/`steps.indices`, so a new `TutStep` "just works." The new step's visual is the **approved 3-tile flow strip** (`SteerFlowStrip`, pure SwiftUI) shown via a `heroFlow` flag on `TutStep`. The coachmark is a SwiftUI overlay in the keyboard idle card, gated by one App-Group integer.

**Tech Stack:** SwiftUI, App Group (`AppGroupService`), `ReplrTheme` tokens. No backend, no new dependencies, no Lottie authoring.

**Spec:** `docs/superpowers/specs/2026-06-05-intent-discoverability-design.md`
**Approved mockups:** `.superpowers/brainstorm/6341-1780694164/content/{intent-tutorial-card,intent-coachmark}.html`

---

## Visual note (resolves the spec's "Lottie placeholder")

The spec text says the new step's visual should be a placeholder **Lottie**, but the **mockup the user actually approved** shows a **3-tile flow strip** (✏️ you type → 🌐 switch to Replr → 💬 on-target replies). This plan builds that strip as a small pure-SwiftUI view (`SteerFlowStrip`) — faithful to what was approved, theme-tokened, zero Lottie-authoring risk. A polished Lottie can replace it in the future tutorial-animation redo (which also redoes the other 5 lo-fi steps). **No hand-authored Lottie is created in this plan.**

## File map

| File | Change |
|---|---|
| `Shared/Constants.swift` | add `intentTipShowCountKey` |
| `Shared/AppGroupService.swift` | add `intentTipShowCount: Int` accessor |
| `ReplrKeyboard/Views/IdlePanelView.swift` | one-time coachmark balloon (dim + tail) over Start; `DownTriangle` shape |
| `Replr/Replr/Features/Onboarding/OnboardingView.swift` | `TutStep.heroFlow` flag, `SteerFlowStrip` view, renderer branch, 6th step entry |

**iOS build (the gate, every task):**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr/Replr && xcodebuild -project Replr.xcodeproj -scheme Replr -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build 2>&1 | tail -5
```
Expect `** BUILD SUCCEEDED **`. SourceKit "No such module / Cannot find ReplrTheme/AppGroupService" diagnostics are FALSE POSITIVES — only `xcodebuild` counts. Use `iPhone 17` (iPhone 16 doesn't exist here). All `ReplrTheme.Color` tokens used below already exist in the codebase: `accent`, `onAccent`, `surface`, `surfaceRaised`, `textSecondary`, `glassBorder`, `brandGradient`, `Radius.md`.

---

### Task 1: Coachmark state (App Group counter)

One integer drives the coachmark: it shows while the count is `< 3`, incrementing each time the idle card appears; dismissing (✕) jams it to `3` so it never returns. Persisted in the App Group so keyboard + app agree and it survives relaunch.

**Files:**
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`

- [ ] **Step 1: Add the key** — in `Shared/Constants.swift`, next to `aboutUserKey`:
```swift
    static let intentTipShowCountKey = "intent_tip_show_count"
```

- [ ] **Step 2: Add the accessor** — in `Shared/AppGroupService.swift`, immediately after the `aboutUser` accessor:
```swift
    /// How many times the in-keyboard "type a direction" coachmark has shown.
    /// Coachmark appears while < 3; dismissing (✕) sets it to 3 so it stops.
    var intentTipShowCount: Int {
        get { defaults.integer(forKey: Constants.intentTipShowCountKey) }
        set { defaults.set(newValue, forKey: Constants.intentTipShowCountKey); defaults.synchronize() }
    }
```
(`defaults.integer(forKey:)` returns `0` when unset — the "new user" start.)

- [ ] **Step 3: Build** — run the build command. Expect `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Shared/Constants.swift Shared/AppGroupService.swift
git commit -m "iOS: App Group counter for the intent coachmark

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Coachmark balloon in the keyboard idle card

A rose balloon above **Start** with a ✕ and a downward tail, over a subtle dim — matching `intent-coachmark.html`. Shown the first few idle-card appearances or until dismissed. The dim is non-interactive so **Start stays tappable underneath**.

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift`

- [ ] **Step 1: Add the state** — in `struct IdlePanelView`, next to the existing `@State private var hasClipboardText` (top of the struct, ~line 6):
```swift
    @State private var showIntentTip = false
```

- [ ] **Step 2: Add the overlay + appear logic.** In `chatContent`, attach these modifiers to the **outer** `VStack(alignment: .leading, spacing: 0)` (opens ~line 25; its modifiers `.padding(.horizontal, 18).padding(.bottom, 8).frame(maxWidth:.infinity, maxHeight:.infinity)` close ~line 103). Add right after `.frame(maxWidth: .infinity, maxHeight: .infinity)`:
```swift
        .overlay {
            if showIntentTip {
                ZStack {
                    // Subtle dim over the card. Non-interactive: Start still works.
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.45 : 0.28))
                        .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        HStack(alignment: .top, spacing: 8) {
                            Text("💡 Want to steer it? Type what you want to say first, then tap Start.")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { showIntentTip = false }
                                AppGroupService.shared.intentTipShowCount = 3
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(ReplrTheme.Color.brandGradient)
                        )
                        .overlay(alignment: .bottom) {
                            DownTriangle()
                                .fill(ReplrTheme.Color.accent)
                                .frame(width: 16, height: 8)
                                .offset(y: 7)
                        }
                        .shadow(color: ReplrTheme.Color.accent.opacity(0.5), radius: 14, x: 0, y: 6)
                        .padding(.horizontal, 26)
                        .padding(.bottom, 60) // float the balloon above the Start button
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            if AppGroupService.shared.intentTipShowCount < 3 {
                showIntentTip = true
                AppGroupService.shared.intentTipShowCount += 1
            } else {
                showIntentTip = false
            }
        }
```

- [ ] **Step 3: Add the `DownTriangle` shape** — at the very end of `ReplrKeyboard/Views/IdlePanelView.swift` (top level, after the final closing brace of the file's last type):
```swift

/// Small downward-pointing triangle for the coachmark balloon tail.
private struct DownTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
```

- [ ] **Step 4: Build** — run the build command. Expect `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "Keyboard: one-time intent coachmark over Start (dim + tail, first few opens / until dismissed)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: "Steer the reply" tutorial step (3-tile flow strip)

Add a 6th step. The carousel derives "Step N of `steps.count`", the dots, and Next/Done from the array + `steps.indices`, so only the array entry + a render branch are needed. The visual is the approved `SteerFlowStrip`.

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Add the `heroFlow` flag to `TutStep`** — in `UsageTutorialView`, change the `TutStep` struct (currently lines ~470–475) by adding one defaulted property at the end. The default keeps the 5 existing entries compiling unchanged:
```swift
    private struct TutStep {
        let animation: LottieAnimation?
        let icon: String
        let title: String
        let body: String
        var heroFlow: Bool = false
    }
```

- [ ] **Step 2: Add the `SteerFlowStrip` nested view** — directly **after** the `TutStep` struct (before `private let steps`), still inside `UsageTutorialView`:
```swift
    /// Approved placeholder hero for the "Steer the reply" step: a 3-tile flow
    /// (you type → switch to Replr → on-target replies). Pure SwiftUI, theme-
    /// tokened; a polished Lottie replaces it in the tutorial-animation redo.
    private struct SteerFlowStrip: View {
        var body: some View {
            HStack(spacing: 7) {
                tile(icon: "square.and.pencil", caption: "you type", sub: "\u{201C}ask her out\u{201D}", highlight: false)
                arrow
                tile(icon: "globe", caption: "switch to\nReplr", sub: nil, highlight: true)
                arrow
                tile(icon: "bubble.left.and.bubble.right.fill", caption: "on-target\nreplies", sub: nil, highlight: false)
            }
            .padding(.horizontal, 14)
        }

        private var arrow: some View {
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ReplrTheme.Color.accent)
        }

        private func tile(icon: String, caption: String, sub: String?, highlight: Bool) -> some View {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(highlight ? ReplrTheme.Color.onAccent : ReplrTheme.Color.accent)
                Text(caption)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(highlight ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                if let sub {
                    Text(sub)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.accent)
                        .lineLimit(1)
                }
            }
            .frame(width: 66, height: 78)
            .background(
                Group {
                    if highlight {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(ReplrTheme.Color.brandGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(ReplrTheme.Color.surfaceRaised)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(highlight ? Color.clear : ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
    }
```

- [ ] **Step 3: Add the 6th step** — append to the `private let steps: [TutStep] = [ … ]` array, right after the last entry (`TutStep(animation: parseLottie(tutSendJSON), icon: "sparkles", …)`):
```swift
        TutStep(animation: nil, icon: "text.cursor",
                title: "Steer the reply",
                body: "Optional: type what you want to say first — like \"ask her to dinner\" — then switch to Replr and tap Start. Your replies come back built around it.",
                heroFlow: true),
```

- [ ] **Step 4: Branch the renderer** — in `stepPage(_:number:)`, the visual `ZStack` currently is `ZStack { RoundedRectangle…fill(surface)…overlay(stroke); if let animation = step.animation, !reduceMotion { LottieView… } else { Image(systemName: step.icon)… } }`. Add the hero branch as the **first** condition. Change the inner `if let animation …` line to:
```swift
                if step.heroFlow {
                    SteerFlowStrip()
                } else if let animation = step.animation, !reduceMotion {
```
(Leave the existing `LottieView(…)` body and the trailing `} else { Image(systemName: step.icon)… }` exactly as they are — you are only inserting the `if step.heroFlow { SteerFlowStrip() } else ` ahead of the existing `if let animation`.)

- [ ] **Step 5: Build** — run the build command. Expect `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/Replr/Features/Onboarding/OnboardingView.swift
git commit -m "Onboarding: add optional 'Steer the reply' tutorial step with flow-strip hero (teaches intent)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Verify end-to-end

**Files:** none expected (fix-ups only).

- [ ] **Step 1: Full build** — run the build command. Expect `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Manual checks (simulator or device)**
  - **Tutorial:** open the app → finish onboarding (or Settings → **How to use Replr**). The carousel now ends with **"Step 6 of 6 · Steer the reply"**, showing the **3-tile flow strip** (you type → switch to Replr → on-target replies, middle tile gradient-filled), the body copy, a 6th page dot, and the final **"Start using Replr →"** button on the last page.
  - **Coachmark:** on a fresh install (or reset — see Step 3), open the Replr keyboard in a chat: the rose **"💡 Want to steer it?…"** balloon shows above **Start** with the downward tail over a subtle dim. **Start is still tappable** through the dim. Tapping **✕** hides it and it **does not return** (even after relaunch). Without dismissing, it stops on its own after ~3 idle-card appearances.
  - Both stay within their frames; the balloon doesn't overlap the keyboard's bottom row; light + dark both read well.

- [ ] **Step 3: Reset helper for re-testing the coachmark** — to see it again: delete + reinstall the app, or in a debug build temporarily set `AppGroupService.shared.intentTipShowCount = 0`. (No feature code change required.)

- [ ] **Step 4: Commit any fix-ups** (targeted `git add`, NOT `git add -A` — unrelated dirty files exist).

---

## Self-review

**Spec coverage:**
- ✅ Tutorial step "Steer the reply" (optional, last, 3 beats) → Task 3 *(visual = approved 3-tile flow strip; polished Lottie deferred to the redo — see Visual note)*
- ✅ Carousel dots / Next-Done extend to the new step → automatic via `steps.count`/`steps.indices` (verified in source)
- ✅ One-time dismissable coachmark over Start, dim + points at Start, within keyboard bounds → Task 2
- ✅ App-Group flag/counter, persists dismissal across relaunch → Task 1
- ✅ Shown "a few opens or until ✕" → counter `< 3` / ✕ sets `3` (Task 1+2)
- ✅ Reduce-Motion: the flow strip is static SwiftUI (no motion concern); existing 5 keep their icon fallback
- ✅ iOS-only, no backend → confirmed
- ✅ Out of scope honored: no in-Replr keypad, no voice, no polished animations, relationship feature untouched

**Placeholder scan:** none — every code step shows complete code; every command has expected output. The deferred polished Lottie is an explicit design choice, not an unfinished step.

**Type/name consistency:** `intentTipShowCount` (Int) + `intentTipShowCountKey` used identically in Constants/AppGroupService/IdlePanelView; `< 3` threshold and `= 3` dismissal agree; `showIntentTip` is the local `@State`; `heroFlow` defaulted on `TutStep` (5 existing entries unchanged) and set `true` only on the new step; `SteerFlowStrip` (defined Task 3 Step 2) is referenced in the renderer branch (Task 3 Step 4); `DownTriangle` (defined Task 2 Step 3) is referenced in the balloon overlay (Task 2 Step 2). All `ReplrTheme.Color.*` tokens referenced exist in the codebase.
