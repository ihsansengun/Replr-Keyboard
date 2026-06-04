# Screenshot Capture (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make Phase-1 screenshot capture production-ready: clean up spike UI, add opt-in screenshot-clutter cleanup, a watch/wait indicator + iOS-26 adaptive hint, and onboarding that grants Photos + teaches the Full-Screen Previews toggle.

**Architecture:** Mostly small, additive changes on the existing rails. Captured screenshot `localIdentifier`s are recorded to the App Group by the keyboard; the companion app batch-deletes them (opt-in) — deletion must run in the app (alerts don't work in keyboards) and always triggers one iOS confirmation. UI pieces reuse existing components.

**Tech Stack:** SwiftUI, PhotoKit, existing `AppGroupService`/`Constants`/`OnboardingStep`.

**⚠️ Verify-on-device note:** UI tasks (4 and 5) are compile-verified only here — they need the user's eye on a real device. Logic tasks (1–3) are fully verifiable by build.

---

## File Map

| File | Change |
|------|--------|
| `ReplrKeyboard/Views/KeyboardView.swift` | Remove spike UI (`spikeResult`, `runPhotosSpike`, `PhotosCapture.run`); record captured ID; strip wait/hint copy |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Remove the 🔬 spike button |
| `ReplrKeyboard/KeyboardViewController.swift` | Record collapse time for the adaptive hint |
| `Shared/Constants.swift` | Add `capturedScreenshotIDsKey` |
| `Shared/AppGroupService.swift` | `recordCapturedScreenshotID`, `capturedScreenshotIDs`, `clearCapturedScreenshotIDs`; `autoClearScreenshots` flag |
| ~~ScreenshotCleaner~~ inlined into SettingsView.swift (app uses explicit refs) |
| `Replr/Replr/Features/Settings/SettingsView.swift` | "Auto-clear captured screenshots" toggle + manual clear |
| `Replr/Replr/App/ReplrApp.swift` | Fire cleanup on foreground when enabled |
| `Replr/Replr/Features/Onboarding/OnboardingView.swift` | Photos-permission step + iOS-26 Full-Screen Previews tip |

---

## Task 1: Remove spike-only UI

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift`, `ReplrKeyboard/Views/KeyboardView.swift`

Context: The 🔬 button, `spikeResult`, `runPhotosSpike`, and `PhotosCapture.run()` were scaffolding. The real helpers (`latestScreenshotID`, `loadImage`) and the `NSPhotoLibraryUsageDescription` fix stay. The dev-screen "Request Photos Access" button stays for now (Task 5 adds real onboarding permission; keep the dev grant as a fallback).

- [ ] **Step 1: Remove the 🔬 button from `IdlePanelView.swift`.** Delete this block (the `// SPIKE — remove after Phase 0` button + result):

```swift
            // SPIKE — remove after Phase 0
            Button { model.runPhotosSpike() } label: {
                Text("🔬 Spike: read latest screenshot")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ReplrTheme.Color.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            if let spikeResult = model.spikeResult {
                Text(spikeResult)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
```

- [ ] **Step 2: Remove `spikeResult` + `runPhotosSpike` from `KeyboardView.swift`.** Delete the line `@Published var spikeResult: String? = nil  // SPIKE — remove after Phase 0` and the whole `// SPIKE — remove after Phase 0` `func runPhotosSpike() { ... }` method.

- [ ] **Step 3: Remove `PhotosCapture.run()` from `KeyboardView.swift`.** Delete the `/// SPIKE — dev-screen diagnostic; safe to remove later.` `static func run() async -> String { ... }` method from the `PhotosCapture` enum. Keep `latestScreenshotID()` and `loadImage(id:)`.

- [ ] **Step 4: Build + commit:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
git add ReplrKeyboard/Views/IdlePanelView.swift ReplrKeyboard/Views/KeyboardView.swift
git commit -m "chore: remove spike-only UI (keep PhotosCapture core)"
```
Expected: `BUILD SUCCEEDED`

---

## Task 2: Record captured screenshot IDs

**Files:**
- Modify: `Shared/Constants.swift`, `Shared/AppGroupService.swift`, `ReplrKeyboard/Views/KeyboardView.swift`

Context: To safely clean up later we must remember the *exact* assets Replr used — never pattern-match. The keyboard appends each processed `localIdentifier` to an App-Group list.

- [ ] **Step 1: Add the key.** In `Shared/Constants.swift`, after `static let selectedToneKey = "selected_tone"`, add:

```swift
    static let capturedScreenshotIDsKey = "captured_screenshot_ids"
    static let autoClearScreenshotsKey  = "auto_clear_screenshots"
```

- [ ] **Step 2: Add the App-Group methods.** In `Shared/AppGroupService.swift`, after `consumeReplies()` (around line 44), add:

```swift
    // MARK: - Captured screenshot tracking (for opt-in cleanup)

    func recordCapturedScreenshotID(_ id: String) {
        var ids = capturedScreenshotIDs()
        guard !ids.contains(id) else { return }
        ids.append(id)
        if let data = try? JSONEncoder().encode(ids) {
            defaults.set(data, forKey: Constants.capturedScreenshotIDsKey)
            defaults.synchronize()
        }
    }

    func capturedScreenshotIDs() -> [String] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.capturedScreenshotIDsKey),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return ids
    }

    func clearCapturedScreenshotIDs() {
        defaults.removeObject(forKey: Constants.capturedScreenshotIDsKey)
        defaults.synchronize()
    }

    var autoClearScreenshots: Bool {
        get { defaults.bool(forKey: Constants.autoClearScreenshotsKey) }
        set { defaults.set(newValue, forKey: Constants.autoClearScreenshotsKey); defaults.synchronize() }
    }
```

- [ ] **Step 3: Record on capture.** In `KeyboardView.swift` `generateFromScreenshot()`, find `self.captureBaselineScreenshotID = assetID   // dedup: never reprocess this one` and add directly after it:

```swift
                AppGroupService.shared.recordCapturedScreenshotID(assetID)
```

- [ ] **Step 4: Build + commit:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
git add Shared/Constants.swift Shared/AppGroupService.swift ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: record captured screenshot localIdentifiers in App Group"
```
Expected: `BUILD SUCCEEDED`

---

## Task 3: App-side batch cleanup + setting + trigger

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift` (inline `ScreenshotCleaner`), `Replr/Replr/App/ReplrApp.swift`

Context: Deletion must run in the app (keyboards can't show the system delete alert). One `deleteAssets` call = one confirmation for all. **Verified:** the app target uses explicit file references (not folder-sync), so a NEW file would not auto-compile — `ScreenshotCleaner` is inlined into `SettingsView.swift` (already in the target). `ReplrApp.swift` already has a `scenePhase` onChange (line ~68) — merge into it.

- [ ] **Step 1: Add `ScreenshotCleaner` to the top of `SettingsView.swift`** (after the imports, before `struct SettingsView`). Also add `import Photos` at the top:

```swift
import Photos

/// Deletes ONLY the screenshots Replr recorded (by localIdentifier). Never touches other photos.
enum ScreenshotCleaner {
    static func pendingCount() -> Int {
        AppGroupService.shared.capturedScreenshotIDs().count
    }

    /// Batch-deletes recorded screenshots. iOS shows one confirmation. Clears the list on success.
    static func clean(completion: ((Bool) -> Void)? = nil) {
        let ids = AppGroupService.shared.capturedScreenshotIDs()
        guard !ids.isEmpty else { completion?(true); return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assets.count > 0 else {
            AppGroupService.shared.clearCapturedScreenshotIDs()   // all already gone
            completion?(true); return
        }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        } completionHandler: { success, _ in
            DispatchQueue.main.async {
                if success { AppGroupService.shared.clearCapturedScreenshotIDs() }
                completion?(success)
            }
        }
    }
}
```

- [ ] **Step 2: Add the Settings toggle + manual clear.** In `SettingsView.swift`, find `aboutSection` in the body's section list and add a new section. First add state at the top of `SettingsView` (near `@State private var memoryEnabled`):

```swift
    @State private var autoClear = AppGroupService.shared.autoClearScreenshots
    @State private var pendingShots = ScreenshotCleaner.pendingCount()
```

Then add this section method (place near `memorySection`):

```swift
    private var screenshotSection: some View {
        settingsSection("Screenshots") {
            HStack {
                Text("Auto-clear captured screenshots")
                Spacer()
                BrandToggle(isOn: $autoClear)
                    .onChange(of: autoClear) { AppGroupService.shared.autoClearScreenshots = $0 }
            }
            if pendingShots > 0 {
                Button {
                    ScreenshotCleaner.clean { _ in pendingShots = ScreenshotCleaner.pendingCount() }
                } label: {
                    Text("Clear \(pendingShots) captured screenshot\(pendingShots == 1 ? "" : "s")")
                        .foregroundStyle(ReplrTheme.Color.accent)
                }
            }
            Text("Only deletes screenshots Replr captured for replies — never your other photos. iOS asks you to confirm.")
                .font(.caption)
                .foregroundStyle(ReplrTheme.Color.textSecondary)
        }
    }
```

Then add `screenshotSection` to the body's `VStack` (after `memorySection`):

```swift
                    memorySection
                    screenshotSection
```

- [ ] **Step 3: Fire cleanup on foreground.** In `ReplrApp.swift`, the existing `.onChange(of: scenePhase) { phase in ... }` (~line 68) — add this inside that closure (read the file to merge cleanly):

```swift
            if phase == .active,
               AppGroupService.shared.autoClearScreenshots,
               ScreenshotCleaner.pendingCount() >= 5 {
                ScreenshotCleaner.clean()
            }
```

- [ ] **Step 4: Build + commit:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
git add Replr/Replr/Features/Settings/SettingsView.swift Replr/Replr/App/ReplrApp.swift
git commit -m "feat: opt-in batch cleanup of captured screenshots (app-side, one confirmation)"
```
Expected: `BUILD SUCCEEDED`

---

## Task 4: Strip wait indicator + iOS-26 adaptive hint

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`, `ReplrKeyboard/Views/KeyboardView.swift`

Context: While collapsed and watching, the strip should feel intentional ("Looking for your screenshot…"). On iOS 26, if nothing is detected within ~5 s of collapsing, surface the Full-Screen Previews tip (the likely cause). Uses a collapse timestamp + the existing watcher.

- [ ] **Step 1: Add a `captureHint` flag to `KeyboardModel`.** In `KeyboardView.swift`, after `var captureBaselineScreenshotID: String? = nil`, add:

```swift
    @Published var showFullScreenPreviewHint: Bool = false   // iOS 26: likely needs Full-Screen Previews off
    var collapseStartedAt: Date? = nil
```

- [ ] **Step 2: Set the collapse time + reset hint.** In `KeyboardViewController.swift`, in the `collapseCancellable` sink, right after `self.model.captureBaselineScreenshotID = PhotosCapture.latestScreenshotID()`, add:

```swift
                self.model.collapseStartedAt = Date()
                self.model.showFullScreenPreviewHint = false
```

- [ ] **Step 3: Detect the timeout in the poll.** In `KeyboardViewController.swift` `startCapturePoll`, replace the watcher block added in Phase 1 with this version (adds the iOS-26 timeout hint):

```swift
                // Phase 1 — Photos watcher: arm on a screenshot newer than the collapse baseline
                let (collapsed, alreadyDetected, baseline, collapsedAt) = await MainActor.run {
                    (self.model.isCollapsed,
                     self.model.detectedScreenshotID != nil,
                     self.model.captureBaselineScreenshotID,
                     self.model.collapseStartedAt)
                }
                if collapsed && !alreadyDetected {
                    if let latest = PhotosCapture.latestScreenshotID(), latest != baseline {
                        NSLog("[Replr][Keyboard] new screenshot detected: %@", latest)
                        await MainActor.run { self.model.detectedScreenshotID = latest }
                    } else if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26,
                              let started = collapsedAt, Date().timeIntervalSince(started) > 5 {
                        await MainActor.run { self.model.showFullScreenPreviewHint = true }
                    }
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
```

- [ ] **Step 4: Update the collapsed strip copy.** In `KeyboardView.swift` `CollapsedStripView`, in the `else` branch (the watching state, `detectedScreenshotID == nil`), replace the two `Text(...)` lines with hint-aware copy:

```swift
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.showFullScreenPreviewHint
                                 ? "Didn't catch that screenshot"
                                 : "Take a screenshot of the chat")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textPrimary)
                            Text(model.showFullScreenPreviewHint
                                 ? "Settings → Screen Capture → turn off Full-Screen Previews"
                                 : "Looking for your screenshot…")
                                .font(.system(size: 11.5))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
```

- [ ] **Step 5: Build + commit:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
git add ReplrKeyboard/KeyboardViewController.swift ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: strip wait indicator + iOS 26 Full-Screen Previews hint"
```
Expected: `BUILD SUCCEEDED`

---

## Task 5: Onboarding — Photos permission + iOS-26 tip (additive; FLAG FOR REVIEW)

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

Context: Conservative + additive — reuse the existing `OnboardingStep` wrapper, do NOT restructure the existing steps or remove Back Tap (deeper restructure is flagged for the user's design review). Add a Photos-permission step so real users can grant Photos (today only the dev screen does), and an iOS-26-only Full-Screen Previews tip. **This is UI the agent cannot see render — user must review on device.**

- [ ] **Step 1: Add `import Photos`** at the top of `OnboardingView.swift` (after `import Combine`).

- [ ] **Step 2: Add a `PhotosPermissionStep`** mirroring `FullAccessStep`'s structure. Insert before the `// MARK: - Root coordinator` line:

```swift
private struct PhotosPermissionStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private var granted: Bool { status == .authorized || status == .limited }

    var body: some View {
        OnboardingStep(
            step: 3, totalSteps: 4,
            sectionLabel: "Permissions",
            headline: "Allow Photos.",
            bodyText: "Replr reads the screenshot you take of a chat to draft replies. It only ever reads the one screenshot you capture — nothing else.",
            onBack: onBack
        ) {
            EmptyView()
        } cta: {
            if granted {
                PrimaryButton(label: "Photos allowed ✓ — Continue →", action: onNext)
            } else {
                VStack(spacing: 12) {
                    PrimaryButton(label: "Allow Photos →") {
                        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                            DispatchQueue.main.async {
                                status = newStatus
                                if newStatus == .authorized || newStatus == .limited {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onNext() }
                                }
                            }
                        }
                    }
                    TertiaryButton(label: "Skip", action: onNext)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add an iOS-26-only `FullScreenPreviewTipStep`** (shows only on iOS 26+; auto-skips otherwise). Insert after `PhotosPermissionStep`:

```swift
private struct FullScreenPreviewTipStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 4, totalSteps: 4,
            sectionLabel: "One setting",
            headline: "Turn off Full-Screen Previews.",
            bodyText: "On iOS 26, screenshots open a full editor instead of saving on their own. Turn this off so Replr can pick them up automatically — Settings → Screen Capture → Full-Screen Previews → off.",
            onBack: onBack
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
    }
}
```

- [ ] **Step 4: Wire both into the coordinator.** In `struct OnboardingView`, replace the `switch step` body so Photos comes after Full Access and the iOS-26 tip shows conditionally. Replace the existing `switch step { ... }` with:

```swift
        Group {
            switch step {
            case 0:
                WelcomeStep(onNext: { step = 1 }, onSignIn: onSignIn)
            case 1:
                AddKeyboardStep(onNext: { step = 2 }, onBack: { step = 0 })
            case 2:
                FullAccessStep(onNext: { step = 3 }, onBack: { step = 1 })
            case 3:
                PhotosPermissionStep(onNext: { step = 4 }, onBack: { step = 2 })
            case 4:
                if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
                    FullScreenPreviewTipStep(onNext: { step = 0; onComplete() }, onBack: { step = 3 })
                } else {
                    // Older iOS auto-saves screenshots — no tip needed; finish.
                    Color.clear.onAppear { step = 0; onComplete() }
                }
            default:
                WelcomeStep(onNext: { step = 1 }, onSignIn: onSignIn)
            }
        }
        .onAppear { if step > 4 { step = 0 } }
```

(Note: this keeps `InstallShortcutStep`/`BackTapStep` in the file but out of the required path — they remain reachable for the optional Back Tap flow. Reordering/relabeling for the full restructure is flagged for user review.)

- [ ] **Step 5: Build + commit:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
git add Replr/Replr/Features/Onboarding/OnboardingView.swift
git commit -m "feat: onboarding Photos permission step + iOS 26 Full-Screen Previews tip (additive)"
```
Expected: `BUILD SUCCEEDED`

---

## Verification checklist

- [ ] All tasks build clean
- [ ] Spike UI gone (no 🔬 button); `PhotosCapture.latestScreenshotID`/`loadImage` intact
- [ ] After a capture, `capturedScreenshotIDs()` grows by one
- [ ] Settings → Screenshots: toggle persists; "Clear N" deletes ONLY recorded shots (one iOS confirmation); count resets
- [ ] **Device review needed:** strip shows "Looking for your screenshot…" while watching; iOS-26 hint appears after ~5 s with no detection
- [ ] **Device review needed:** onboarding shows Photos step; iOS-26 shows the Full-Screen Previews tip, older iOS skips it
- [ ] Existing Back Tap flow still works (untouched)
