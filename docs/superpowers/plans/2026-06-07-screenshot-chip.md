# Screenshot Chip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a compact "📸 Screenshot detected" chip at the top of the idle keyboard panel when the user took a screenshot in the last 5 minutes before opening the keyboard — so screenshots of Tinder profiles, Instagram stories, etc. are surfaced for one-tap reply generation.

**Architecture:** On `viewDidAppear`, `ScreenshotChipService` (inlined in `KeyboardView.swift`, same as the existing `PhotosCapture` enum) checks whether the current `captureBaselineScreenshotID` asset was created within the last 5 minutes. If yes (and not previously consumed), it sets `KeyboardModel.pendingScreenshotChip`. A compact chip banner renders in `IdlePanelView` above the existing content. Tapping it routes through the existing `detectedScreenshotID` → `generateFromScreenshot()` path unchanged. A 30-second timer auto-dismisses the chip. Explicit X-dismiss and tap-to-use both write `lastConsumedScreenshotID` so the same screenshot never resurfaces.

**Tech Stack:** Swift, SwiftUI, Photos framework (`PHAsset`, `PHPhotoLibrary`), Swift Testing framework (existing test target), Xcode / xcodebuild.

---

## File Map

| Action | File | What changes |
|---|---|---|
| Modify | `Shared/Constants.swift` | Add `lastConsumedScreenshotIDKey` |
| Modify | `Shared/AppGroupService.swift` | Add `lastConsumedScreenshotID: String?` property |
| Modify | `ReplrKeyboard/Views/KeyboardView.swift` | Add `ScreenshotChipService` class (new `MARK` section, inlined like `PhotosCapture`); add `pendingScreenshotChip`, `screenshotChipService`, `activateScreenshotChip()`, `useScreenshotChip()`, `dismissScreenshotChip()` to `KeyboardModel` |
| Modify | `ReplrKeyboard/KeyboardViewController.swift` | Call `model.activateScreenshotChip()` in `viewDidAppear` |
| Modify | `ReplrKeyboard/Views/IdlePanelView.swift` | Add `screenshotChipBanner` view + wire into body |
| Modify | `Replr/ReplrTests/ReplrTests.swift` | Add `lastConsumedScreenshotID` round-trip test |

> **Why inline?** `KeyboardView.swift` has an existing comment: "Inlined here because the keyboard target does not auto-include new files." `ScreenshotChipService` follows the same convention as `PhotosCapture` — both live in `// MARK:` sections at the bottom of `KeyboardView.swift`.

---

## Task 1: Add Constants key and AppGroupService property

**Files:**
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`
- Test: `Replr/ReplrTests/ReplrTests.swift`

- [ ] **Step 1: Write the failing test first**

Open `Replr/ReplrTests/ReplrTests.swift` and replace the placeholder:

```swift
import Testing
@testable import Replr

struct ReplrTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func lastConsumedScreenshotIDRoundTrip() {
        let svc = AppGroupService.shared
        // Save and read back
        svc.lastConsumedScreenshotID = "test-asset-abc-123"
        #expect(svc.lastConsumedScreenshotID == "test-asset-abc-123")
        // Clear and verify nil
        svc.lastConsumedScreenshotID = nil
        #expect(svc.lastConsumedScreenshotID == nil)
    }
}
```

- [ ] **Step 2: Run test — expect COMPILE FAILURE** (property doesn't exist yet)

In Xcode: ⌘U → scheme `ReplrTests`. Expected: compile error "value of type 'AppGroupService' has no member 'lastConsumedScreenshotID'".

- [ ] **Step 3: Add the key to Constants**

In `Shared/Constants.swift`, inside the `enum Constants` body, after the line `static let sessionRegenerateCountKey  = "session_regenerate_count"`:

```swift
    static let lastConsumedScreenshotIDKey = "last_consumed_screenshot_id"
```

- [ ] **Step 4: Add the property to AppGroupService**

In `Shared/AppGroupService.swift`, inside the `// MARK: - Captured screenshot tracking` section (after `clearCapturedScreenshotIDs()`), add:

```swift
    /// The localIdentifier of the last screenshot that was explicitly consumed (used to generate
    /// replies) or dismissed (X button) via the screenshot chip. Prevents the same screenshot
    /// from resurfacing on subsequent keyboard opens within the 5-minute detection window.
    var lastConsumedScreenshotID: String? {
        get { defaults.string(forKey: Constants.lastConsumedScreenshotIDKey) }
        set {
            if let v = newValue { defaults.set(v, forKey: Constants.lastConsumedScreenshotIDKey) }
            else { defaults.removeObject(forKey: Constants.lastConsumedScreenshotIDKey) }
            defaults.synchronize()
        }
    }
```

- [ ] **Step 5: Run test — expect PASS**

In Xcode: ⌘U → scheme `ReplrTests`.
Expected: `lastConsumedScreenshotIDRoundTrip` passes.

- [ ] **Step 6: Commit**

```bash
cd ~/Developer/Replr
git add Shared/Constants.swift Shared/AppGroupService.swift Replr/ReplrTests/ReplrTests.swift
git commit -m "$(cat <<'EOF'
feat: add lastConsumedScreenshotID to AppGroupService

Persists the localIdentifier of the most recently consumed/dismissed
screenshot chip so the same screenshot never resurfaces on reopen.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add ScreenshotChipService inline in KeyboardView.swift

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

`ScreenshotChipService` is inlined at the bottom of `KeyboardView.swift` in a new `// MARK:` section, immediately before the existing `// MARK: - PhotosCapture` section. This follows the same pattern as `PhotosCapture`.

- [ ] **Step 1: Add ScreenshotChipService class**

At the bottom of `ReplrKeyboard/Views/KeyboardView.swift`, immediately BEFORE the line `// MARK: - PhotosCapture (Phase 1 — screenshot capture; run() kept for dev spike button)`, insert:

```swift
// MARK: - ScreenshotChipService
// Inlined here (same reason as PhotosCapture below — keyboard target does not auto-include new files).

/// Detects whether the `captureBaselineScreenshotID` — the newest screenshot that existed
/// when the keyboard opened — was taken within the last 5 minutes. If so, surfaces it as a
/// compact "📸 Screenshot detected" chip in the idle panel. The chip lives for 30 seconds;
/// tapping it routes through the existing `generateFromScreenshot()` path unchanged.
@MainActor
final class ScreenshotChipService {
    private weak var model: KeyboardModel?
    private var dismissTimer: Timer?

    init(model: KeyboardModel) { self.model = model }

    /// Call from viewDidAppear, after captureBaselineScreenshotID is set.
    /// Silently no-ops if Photos is not authorized, asset is too old, or asset was already consumed/dismissed.
    func activate(baselineAssetID: String?) {
        guard let id = baselineAssetID else { return }
        guard id != AppGroupService.shared.lastConsumedScreenshotID else { return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject,
              let createdAt = asset.creationDate,
              createdAt >= Date().addingTimeInterval(-5 * 60) else { return }
        model?.pendingScreenshotChip = id
        scheduleDismiss()
    }

    /// Called when user taps X. Marks the screenshot as consumed so it won't resurface.
    func dismiss() {
        cancelTimer()
        if let id = model?.pendingScreenshotChip {
            AppGroupService.shared.lastConsumedScreenshotID = id
        }
        model?.pendingScreenshotChip = nil
    }

    /// Called when user taps the chip body to generate. Returns the assetID to use.
    /// Marks the screenshot as consumed and clears the chip.
    func consume() -> String? {
        cancelTimer()
        guard let id = model?.pendingScreenshotChip else { return nil }
        AppGroupService.shared.lastConsumedScreenshotID = id
        model?.pendingScreenshotChip = nil
        return id
    }

    // 30-second auto-dismiss: does NOT mark consumed — the user may reopen the keyboard
    // and still want to use this screenshot.
    private func scheduleDismiss() {
        cancelTimer()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissTimer = nil
                self?.model?.pendingScreenshotChip = nil
            }
        }
    }

    private func cancelTimer() {
        dismissTimer?.invalidate()
        dismissTimer = nil
    }
}

```

- [ ] **Step 2: Build to verify no compile errors**

```bash
cd ~/Developer/Replr/Replr
xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/Replr
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: add ScreenshotChipService (inlined in KeyboardView)

Detects the pre-open baseline screenshot within a 5-minute window and
exposes it to KeyboardModel for the chip UI. 30-second auto-dismiss;
consume/dismiss both write lastConsumedScreenshotID.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Wire ScreenshotChipService into KeyboardModel

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` (KeyboardModel section)

- [ ] **Step 1: Add pendingScreenshotChip and chip methods to KeyboardModel**

In `KeyboardView.swift`, inside `final class KeyboardModel: ObservableObject`, after the line `@Published var showFullScreenPreviewHint: Bool = false`, add:

```swift
    /// localIdentifier of a pre-keyboard-open screenshot within the 5-minute detection window.
    /// Non-nil → the idle panel shows a compact "📸 Screenshot detected" chip.
    @Published var pendingScreenshotChip: String? = nil
```

Then, after all `@Published` declarations and before `var onReplySelected`, add:

```swift
    // Lazy so self is fully initialized before the service captures it.
    private(set) lazy var screenshotChipService: ScreenshotChipService = ScreenshotChipService(model: self)
```

Then, after the `dismissDetectedScreenshot()` function, add the three chip methods:

```swift
    /// Call from KeyboardViewController.viewDidAppear — checks if the baseline screenshot
    /// (newest screenshot that existed when the keyboard opened) is recent enough to chip.
    func activateScreenshotChip() {
        screenshotChipService.activate(baselineAssetID: captureBaselineScreenshotID)
    }

    /// User tapped the chip body → generate replies from it.
    func useScreenshotChip() {
        guard let id = screenshotChipService.consume() else { return }
        // Route through the existing detected-screenshot path — no logic duplication.
        detectedScreenshotID = id
        generateFromScreenshot()
    }

    /// User tapped X → dismiss the chip and prevent it from resurfacing.
    func dismissScreenshotChip() {
        screenshotChipService.dismiss()
    }
```

- [ ] **Step 2: Build to verify**

```bash
cd ~/Developer/Replr/Replr
xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/Replr
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: add pendingScreenshotChip + chip methods to KeyboardModel

KeyboardModel now owns ScreenshotChipService and exposes
activateScreenshotChip / useScreenshotChip / dismissScreenshotChip.
Tap-to-use routes through the existing generateFromScreenshot() path.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Wire viewDidAppear in KeyboardViewController

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Add activateScreenshotChip() call**

In `KeyboardViewController.swift`, inside `override func viewDidAppear(_ animated: Bool)`, after the line `model.needsGlobeKey = needsInputModeSwitchKey`, add:

```swift
        // Check for a screenshot taken before the keyboard opened (within 5-minute window).
        // captureBaselineScreenshotID was already set in viewWillAppear.
        model.activateScreenshotChip()
```

The full `viewDidAppear` after the change:

```swift
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if hasFullAccess {
            AppGroupService.shared.keyboardInstalled = true
            AppGroupService.shared.fullAccessGranted = true
        }
        model.needsGlobeKey = needsInputModeSwitchKey
        // Check for a screenshot taken before the keyboard opened (within 5-minute window).
        // captureBaselineScreenshotID was already set in viewWillAppear.
        model.activateScreenshotChip()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self else { return }
            let draft = self.textDocumentProxy.documentContextBeforeInput ?? ""
            self.model.pendingContext = draft
        }
    }
```

- [ ] **Step 2: Build to verify**

```bash
cd ~/Developer/Replr/Replr
xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/Replr
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "$(cat <<'EOF'
feat: activate screenshot chip in viewDidAppear

Calls model.activateScreenshotChip() after the keyboard fully connects,
when captureBaselineScreenshotID is already set from viewWillAppear.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Add chip UI banner to IdlePanelView

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift`

- [ ] **Step 1: Add the chip banner view**

In `IdlePanelView.swift`, inside `struct IdlePanelView: View`, add a new private computed property after `screenshotReadyContent` (around line 156):

```swift
    /// Compact chip shown when a pre-open screenshot is within the 5-minute window.
    /// Sits between KeyboardHeader and the main idle content — does not replace it.
    private var screenshotChipBanner: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { model.useScreenshotChip() }
            } label: {
                HStack(spacing: 6) {
                    Text("📸")
                        .font(.system(size: 13))
                    Text("Screenshot detected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                }
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(ReplrTheme.Color.surfaceRaised)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(ReplrTheme.Color.accent.opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { model.dismissScreenshotChip() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(ReplrTheme.Color.surfaceRaised))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }
```

- [ ] **Step 2: Wire the banner into the body**

In `IdlePanelView.swift`, the `body` property currently reads:

```swift
    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, onOpenSettings: {
                teachingPage = 0
                withAnimation(.easeInOut(duration: 0.18)) { showTeachingPanel = true }
            })
            if model.detectedScreenshotID != nil {
                screenshotReadyContent
            } else if model.inputMode == .chat {
                chatContent
            } else {
                emailContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
        .overlay { if showTeachingPanel { teachingPanel } }
    }
```

Replace it with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, onOpenSettings: {
                teachingPage = 0
                withAnimation(.easeInOut(duration: 0.18)) { showTeachingPanel = true }
            })
            if model.pendingScreenshotChip != nil {
                screenshotChipBanner
            }
            if model.detectedScreenshotID != nil {
                screenshotReadyContent
            } else if model.inputMode == .chat {
                chatContent
            } else {
                emailContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
        .overlay { if showTeachingPanel { teachingPanel } }
    }
```

- [ ] **Step 3: Build to verify**

```bash
cd ~/Developer/Replr/Replr
xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run unit tests**

In Xcode: ⌘U → scheme `ReplrTests`.
Expected: all tests pass (including `lastConsumedScreenshotIDRoundTrip`).

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Replr
git add ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "$(cat <<'EOF'
feat: add screenshot chip banner to idle keyboard panel

Compact '📸 Screenshot detected' chip appears between KeyboardHeader
and idle content when a pre-open screenshot is within the 5-min window.
Tap body → generate replies; tap X → dismiss and suppress.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Manual device verification

Run on a real device (chip detection requires a real Photos library; simulator has no screenshots).

- [ ] **Scenario 1 — Basic happy path**
  1. Lock screen, take a screenshot
  2. Open a chat app (WhatsApp, Messages) within 5 minutes, activate Replr keyboard
  3. **Expected:** `📸 Screenshot detected` chip appears at top of idle panel

- [ ] **Scenario 2 — Tap to generate**
  1. After chip appears, tap it
  2. **Expected:** keyboard transitions to `.loading`, replies appear

- [ ] **Scenario 3 — Auto-dismiss**
  1. Chip appears, wait 30 seconds without touching it
  2. **Expected:** chip fades out, idle panel remains unchanged

- [ ] **Scenario 4 — Explicit dismiss (X)**
  1. Chip appears, tap X
  2. **Expected:** chip disappears immediately; keyboard stays in idle

- [ ] **Scenario 5 — No resurface after consume**
  1. Tap chip → generate replies
  2. Close and reopen keyboard within 5 minutes
  3. **Expected:** chip does NOT reappear for the same screenshot

- [ ] **Scenario 6 — No resurface after X-dismiss**
  1. Chip appears, tap X
  2. Close and reopen keyboard within 5 minutes
  3. **Expected:** chip does NOT reappear

- [ ] **Scenario 7 — Old screenshot (> 5 min) not surfaced**
  1. Take a screenshot, wait 6 minutes, open keyboard
  2. **Expected:** no chip appears

- [ ] **Scenario 8 — Back Tap still works**
  1. Chip showing → trigger Back Tap shortcut
  2. **Expected:** keyboard transitions to `.loading` via Back Tap path normally; chip disappears when state changes

- [ ] **Scenario 9 — No chip on fresh keyboard with no recent screenshot**
  1. Open keyboard having taken no screenshots in the past 5 minutes
  2. **Expected:** no chip, normal idle panel

---

## Architecture Notes

**Why `captureBaselineScreenshotID` and not a new fetch?**
`viewWillAppear` already runs `PhotosCapture.latestScreenshotID()` to set the baseline. `ScreenshotChipService.activate()` re-uses that result — the newest screenshot at keyboard-open time. A separate fetch would return the same ID; this avoids double work and keeps Photos access minimal.

**Why not use `detectedScreenshotID` directly?**
`detectedScreenshotID` triggers `screenshotReadyContent` — a full-panel takeover replacing the idle content. The chip is intentionally compact and non-intrusive. Two properties, two UI treatments.

**Why `useScreenshotChip()` routes through `detectedScreenshotID`?**
`generateFromScreenshot()` already handles credit check, image loading, App Group write, state transitions, session creation, and contact resolution. Setting `detectedScreenshotID = id` and calling `generateFromScreenshot()` reuses all of that without duplication.
