# Screenshot Capture (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user get replies by taking a normal screenshot while the keyboard is collapsed — no Back Tap, no Shortcut.

**Architecture:** Reuse existing rails. The collapsed strip becomes the "watching" state; a 250ms Photos poll (added to the existing `startCapturePoll` loop) detects a screenshot newer than the moment-of-collapse baseline and arms a "tap to generate" strip; tapping runs `KeyboardModel.generateFromScreenshot()`, which mirrors the in-keyboard `generateEmailReply()` path (same `ReplyService`, contact resolution, memory, session save with cost/tone) sourced from the detected `PHAsset`.

**Tech Stack:** SwiftUI, PhotoKit (`PHAsset`/`PHImageManager`), existing `ReplyService`/`AppGroupService`/`CaptureSession`.

**Note on TDD:** Like the spike, this is PhotoKit I/O + UI with no pure unit-testable logic; per-task verification is "compiles clean," and the real verification is the on-device run in the final task. Back Tap and `GenerateReplyIntent` are untouched — this is purely additive.

---

## File Map

| File | Change |
|------|--------|
| `ReplrKeyboard/Views/KeyboardView.swift` | Evolve `PhotosSpike`→`PhotosCapture` (+`latestScreenshotID`, `loadImage`); add model state + `generateFromScreenshot()`; adapt `CollapsedStripView`; update `CoachmarkBalloon` copy |
| `ReplrKeyboard/KeyboardViewController.swift` | Set capture baseline on collapse; add Photos-watch block to `startCapturePoll` |

---

## Task 1: Evolve PhotosSpike → PhotosCapture

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Context: The spike's `PhotosSpike` enum (inlined at the bottom of `KeyboardView.swift`) already proves Photos reads work. Promote it to the real `PhotosCapture` helper with two methods the feature needs: a lightweight latest-screenshot-id lookup (no image load, for the watcher) and a full image load (for generation). Keep `run()` so the dev spike button still works during Phase 1 testing.

- [ ] **Step 1: Replace the `enum PhotosSpike { ... }` block** (the `// MARK: - PhotosSpike (SPIKE — remove after Phase 0)` section) with:

```swift
// MARK: - PhotosCapture (Phase 1 — screenshot capture; run() kept for dev spike button)
// Inlined here because the keyboard target does not auto-include new files.

enum PhotosCapture {
    /// localIdentifier of the newest screenshot, or nil if none / not authorized. No image load.
    static func latestScreenshotID() -> String? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 1
        opts.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        return PHAsset.fetchAssets(with: .image, options: opts).firstObject?.localIdentifier
    }

    /// Loads the full UIImage for a screenshot localIdentifier.
    static func loadImage(id: String) async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else { return nil }
        return await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = false
            opts.isSynchronous = false
            opts.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: opts
            ) { image, info in
                if let image, (info?[PHImageResultIsDegradedKey] as? Bool) != true {
                    cont.resume(returning: image)
                } else if (info?[PHImageErrorKey] as? Error) != nil {
                    cont.resume(returning: nil)
                }
                // else: degraded frame — wait for the full-quality delivery
            }
        }
    }

    /// SPIKE — dev-screen diagnostic; safe to remove later.
    static func run() async -> String {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return "✗ Photos not authorized (status=\(status.rawValue))."
        }
        guard let id = latestScreenshotID(), let image = await loadImage(id: id) else {
            return "✗ No screenshot found / load failed."
        }
        let mem = os_proc_available_memory()
        return "✓ loaded \(Int(image.size.width))×\(Int(image.size.height)) · headroom \(String(format: "%.1f", Double(mem)/1_048_576))MB"
    }
}
```

- [ ] **Step 2: Update the one call site.** In `KeyboardModel.runPhotosSpike()`, change `await PhotosSpike.run()` to `await PhotosCapture.run()`.

- [ ] **Step 3: Build:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit:**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: PhotosCapture helper (latestScreenshotID + loadImage) for screenshot capture"
```

---

## Task 2: Add model state + generateFromScreenshot()

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Context: `generateFromScreenshot()` mirrors `generateEmailReply()` (same memory fetch, contact resolution, session save, credit deduction, cost/tone fields) but sourced from the detected `PHAsset` and using `generateReplies(screenshot:...)`. Two new properties hold the detected screenshot and the dedup baseline.

- [ ] **Step 1: Add the state.** Find `@Published var spikeResult: String? = nil  // SPIKE — remove after Phase 0` and add directly after it:

```swift
    @Published var detectedScreenshotID: String? = nil   // a new screenshot awaiting the confirm tap
    var captureBaselineScreenshotID: String? = nil        // newest screenshot at moment-of-collapse (dedup)
```

- [ ] **Step 2: Add the method.** Find `func runPhotosSpike() {` and insert this method directly *before* it:

```swift
    /// Phase 1 — generate replies from the detected screenshot (mirrors generateEmailReply).
    func generateFromScreenshot() {
        guard let assetID = detectedScreenshotID else { return }
        let required = AppGroupService.shared.creditsRequired
        guard AppGroupService.shared.effectiveCreditBalance >= required else {
            withAnimation(.easeInOut(duration: 0.2)) { isCollapsed = false; state = .paywall }
            return
        }
        let context = pendingContext.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeInOut(duration: 0.2)) { isCollapsed = false; state = .loading }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let image = await PhotosCapture.loadImage(id: assetID) else {
                self.detectedScreenshotID = nil
                withAnimation { self.state = .error("Couldn't read the screenshot. Try again.") }
                return
            }
            let previousContext: String?
            if let contactID = AppGroupService.shared.currentContactID {
                let summaries = AppGroupService.shared.recentSummaries(
                    forContactID: contactID, limit: AppGroupService.shared.memoryDepth)
                previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
            } else {
                previousContext = nil
            }
            do {
                let result = try await ReplyService.shared.generateReplies(
                    screenshot: image,
                    tone: self.selectedTone,
                    summary: context.isEmpty ? nil : context,
                    previousContext: previousContext
                )
                let resolved = self.resolveContact(from: result)
                self.contactName = resolved.name
                var session = CaptureSession(
                    id: UUID(), timestamp: Date(), thumbnailData: nil,
                    contextHint: context.isEmpty ? nil : context,
                    generatedReplies: result.replies, selectedReply: nil,
                    llmSummary: result.summary, contactID: resolved.id, contactName: resolved.name
                )
                session.toneName = self.selectedTone.name
                session.previousContext = previousContext
                session.modelUsed = AppGroupService.shared.selectedModel
                session.inputTokens = result.inputTokens
                session.outputTokens = result.outputTokens
                session.costUsd = result.costUsd
                if !AppGroupService.shared.devMode { AppGroupService.shared.creditBalance -= required }
                AppGroupService.shared.appendCaptureSession(session)
                AppGroupService.shared.saveReplies(result.replies)
                self.currentReplies = result.replies
                self.repliesGeneratedInMode = .chat
                self.hasAnySessions = true
                self.captureBaselineScreenshotID = assetID   // dedup: never reprocess this one
                self.detectedScreenshotID = nil
                withAnimation(.easeInOut(duration: 0.2)) { self.state = .replies(result.replies) }
            } catch {
                self.detectedScreenshotID = nil
                withAnimation { self.state = .error(error.localizedDescription) }
            }
        }
    }

```

- [ ] **Step 3: Build:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit:**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: KeyboardModel.generateFromScreenshot + capture state"
```

---

## Task 3: Wire the Photos watcher into the poll loop

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

Context: Two hooks. (a) When the keyboard collapses, record the current newest screenshot id as the baseline, so only *newer* screenshots count. (b) Each poll tick, while collapsed and nothing detected yet, compare the newest screenshot id to the baseline and arm `detectedScreenshotID` if it changed.

- [ ] **Step 1: Set the baseline on collapse.** In `collapseCancellable`'s sink, find:

```swift
                let ctx = self.model.pendingContext
                AppGroupService.shared.savePendingContext(ctx)
```

Insert directly before that line:

```swift
                self.model.captureBaselineScreenshotID = PhotosCapture.latestScreenshotID()
```

- [ ] **Step 2: Add the watcher to the poll loop.** In `startCapturePoll`, find the end of the if/else-if chain and the sleep:

```swift
                } else if let error = AppGroupService.shared.consumeError() {
                    NSLog("[Replr][Keyboard] poll error: %@", error)
                    await MainActor.run {
                        self.model.isCaptureMode = false
                        self.model.isCollapsed = false
                        withAnimation { self.model.state = .error(error) }
                    }
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
```

Insert the watcher block between the closing `}` of the chain and the `try? await Task.sleep` line:

```swift
                } else if let error = AppGroupService.shared.consumeError() {
                    NSLog("[Replr][Keyboard] poll error: %@", error)
                    await MainActor.run {
                        self.model.isCaptureMode = false
                        self.model.isCollapsed = false
                        withAnimation { self.model.state = .error(error) }
                    }
                }

                // Phase 1 — Photos watcher: arm on a screenshot newer than the collapse baseline
                let (collapsed, alreadyDetected, baseline) = await MainActor.run {
                    (self.model.isCollapsed,
                     self.model.detectedScreenshotID != nil,
                     self.model.captureBaselineScreenshotID)
                }
                if collapsed && !alreadyDetected,
                   let latest = PhotosCapture.latestScreenshotID(), latest != baseline {
                    NSLog("[Replr][Keyboard] new screenshot detected: %@", latest)
                    await MainActor.run { self.model.detectedScreenshotID = latest }
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
```

- [ ] **Step 3: Build:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit:**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: Photos watcher in poll loop + baseline on collapse"
```

---

## Task 4: Adapt the collapsed strip + coachmark copy

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Context: The collapsed strip's tap card currently says "Triple-tap the back" and un-collapses on tap. Make it adapt: while watching it prompts for a screenshot (tap = expand, an escape hatch); once `detectedScreenshotID` is set it becomes the "tap to generate" CTA (tap = `generateFromScreenshot()`).

- [ ] **Step 1: Replace the strip's `Button { ... } label: { HStack ... }`.** Find this block in `CollapsedStripView`:

```swift
            // Capture card — entire card is the tap target
            Button {
                dismissCoachmark()
                withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = false }
            } label: {
                HStack(spacing: 10) {
                    TapGlyph()

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Triple-tap the back of your phone")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("to capture this chat")
                            .font(.system(size: 11.5))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 36, height: 36)
                }
```

Replace it with:

```swift
            // Capture card — entire card is the tap target. Adapts to the watcher state.
            Button {
                if model.detectedScreenshotID != nil {
                    model.generateFromScreenshot()
                } else {
                    dismissCoachmark()
                    withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = false }
                }
            } label: {
                HStack(spacing: 10) {
                    if model.detectedScreenshotID != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(ReplrTheme.Color.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Screenshot ready")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(ReplrTheme.Color.accent)
                            Text("Tap to generate replies")
                                .font(.system(size: 11.5))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ReplrTheme.Color.accent)
                            .frame(width: 36, height: 36)
                    } else {
                        TapGlyph()
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Take a screenshot of the chat")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textPrimary)
                            Text("Replies appear here automatically")
                                .font(.system(size: 11.5))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
```

- [ ] **Step 2: Update the coachmark copy.** Find in `CoachmarkBalloon`:

```swift
            Text("① Keyboard's minimised. ② Triple-tap the back.")
```

Replace with:

```swift
            Text("① Keyboard's minimised. ② Take a screenshot of the chat.")
```

- [ ] **Step 3: Build:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit:**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: collapsed strip arms 'tap to generate' on screenshot detect"
```

---

## Task 5: On-device test (user-run)

**Files:** none — the real experiment.

- [ ] **Step 1: Hand off with these instructions:**
  1. Pull `main`, Run on a physical iPhone.
  2. Ensure Photos is granted (dev screen → "Request Photos Access" if needed) and the keyboard has Full Access.
  3. Open a chat (e.g. WhatsApp), tap the text field → Replr keyboard appears.
  4. Tap **"Start capture ↓"** to collapse. Strip should read *"Take a screenshot of the chat."*
  5. Take a screenshot. **Do not tap the preview thumbnail** — let it commit.
  6. Within ~1–2 s the strip should flip to *"✨ Screenshot ready — Tap to generate."* Tap it.
  7. Replies for that chat should appear in the keyboard.

- [ ] **Step 2: Report findings:**
  - Did the strip auto-flip to "ready" after the screenshot (→ **auto-save works, zero-tap confirmed**), or did it only flip after you manually saved (→ one-tap save needed)? **This answers the open auto-save question.**
  - Were the replies correct for the chat?
  - History (Replies tab) shows the session with tone + cost?
  - Any crash or wrong-screenshot pickup?

- [x] **Step 3: Record the outcome** in this plan and decide Phase 2 (onboarding/permission UX + slim-bar redesign) based on what the real behavior turned out to be.

  **OUTCOME (2026-06-04, on device): WORKS. 🎉**
  - End-to-end confirmed: collapse → screenshot → strip arms "✨ Screenshot ready" → tap → correct replies, no Back Tap.
  - **Key finding — the auto-save question is answered:** iOS 26's default "Full-Screen Previews" makes a screenshot wait for a manual action, so it does NOT auto-commit. **Turning off Settings → Screen Capture → Full-Screen Previews** reverts to the corner thumbnail that auto-saves in ~3 s — and then the watcher catches it with **zero taps**. So the zero-tap flow is real, gated on that one device setting.
  - **Phase 2 direction (per user):** onboarding should (a) explain the Full-Screen Previews toggle as the recommended setup for auto-capture, and (b) keep Back Tap as an optional/advanced path. Also: clutter mitigation (screenshots accumulate) and the ~3 s "looking for screenshot…" wait indicator. Spike-only UI (keyboard 🔬 button, `runPhotosSpike`) to be cleaned up in Phase 2.

---

## Verification checklist

- [ ] Each task builds clean for simulator
- [ ] On device: collapse → screenshot → strip arms → tap → real replies, no Back Tap
- [ ] Dedup: the same screenshot doesn't re-fire; a brand-new screenshot does
- [ ] Unrelated screenshots taken while NOT collapsed do not arm anything
- [ ] Capture history shows tone + model + cost for the new session
- [ ] Auto-save behavior recorded (the key open question)
