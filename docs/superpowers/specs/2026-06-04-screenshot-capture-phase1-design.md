# Screenshot Capture (Phase 1) — Design Spec

**Date:** 2026-06-04
**Status:** Awaiting user review
**Depends on:** Phase 0 spike — PASSED (keyboard reads screenshots, ~137 MB headroom worst case)

---

## Goal

Let the user get replies by taking a **normal screenshot** — no Back Tap, no Shortcut. The keyboard watches Photos while collapsed; a new screenshot triggers reply generation directly in the keyboard.

This is the **core magic** only. The slim-bar-as-default redesign and the onboarding/Back-Tap cleanup are deliberately **Phase 2/3** — Phase 1 proves the mechanism on existing rails so it's testable on-device fast.

---

## User flow (Phase 1)

1. In a chat, user taps the text field → Replr keyboard appears (existing idle panel).
2. User taps **"Start capture ↓"** → keyboard collapses to the existing strip (this now also **arms the Photos watcher**). Strip reads: *"📸 Take a screenshot of the chat."*
3. User takes a normal screenshot (volume + side button).
4. The keyboard's poll spots a **new** screenshot in Photos → strip flips to *"✨ Screenshot ready — tap to generate."*
5. User taps the strip → keyboard reads the screenshot, calls the API (current tone + typed context + memory), expands, and shows the replies panel.
6. Tap a reply to insert (existing behavior).

Auto-detect + one confirming tap (decided in brainstorm) — no wasted credits on unrelated screenshots, and the tap absorbs the Photos save-delay.

---

## Architecture

Phase 1 reuses existing rails:

- **Watching state = the existing `isCollapsed` strip.** No new keyboard state enum case in Phase 1. Collapsing arms the watcher; un-collapsing (or leaving) disarms it.
- **Generation = the existing `ReplyService.generateReplies` path** already used in-keyboard by `generateEmailReply()` — same contact resolution, memory fetch, session save (incl. the new cost/tone fields), and `.replies` transition.
- **Reading the screenshot = the spike's proven approach** (`PHImageManager.requestImageDataAndOrientation`, raw bytes, no decode). The spike code is promoted from throwaway to real.

### New pieces

**1. Photos watcher (in `KeyboardViewController.startCapturePoll`, or a sibling poll)**
- When the keyboard collapses, record a **baseline**: the `localIdentifier` of the current newest screenshot (nil if none).
- While collapsed, each poll tick fetches the newest screenshot asset. If its `localIdentifier` differs from the baseline → a new screenshot exists → set `model.detectedScreenshotID = <id>` and surface the "ready" strip state.
- Dedup: once a screenshot is detected/processed, its id becomes the new baseline so it never fires twice.

**2. `KeyboardModel.generateFromScreenshot()`**
- Mirrors `generateEmailReply()` but sourced from the detected `PHAsset` instead of the clipboard:
  - Credit gate (→ `.paywall` if insufficient), same as email.
  - Read image data for `detectedScreenshotID` via `PHImageManager`.
  - Build a `UIImage` from the data and pass it to `ReplyService` (which `compressForUpload`s it to ~180 KB so the upload stays small). **Honesty note:** the spike measured the raw-data read + base64 (no decode). This full path adds a `UIImage` decode + recompress — a transient peak of roughly ~30 MB for a full-res screenshot. That sits comfortably inside the measured ~137 MB worst-case headroom (~4× margin), but it was **not** directly spiked. Phase 1's *first on-device run* exercises this exact path, so it is self-validating — if it ever crashes on a low-RAM device we switch `generateFromScreenshot` to send the raw bytes (skip the decode) at the cost of a larger upload.
  - Call `ReplyService.shared.generateReplies(screenshot:tone:summary:previousContext:)` with current tone, `pendingContext`, and memory summaries (same memory logic as email mode).
  - Save a `CaptureSession` (thumbnail, replies, summary, contact, **toneName/modelUsed/inputTokens/outputTokens/costUsd**).
  - `state = .replies(...)`, expand from the strip.
- On error → `.error`. On success → existing replies UI.

**3. Strip copy + tap action (in `IdlePanelView` collapsed strip / `KeyboardView`)**
- Collapsed strip shows *"📸 Take a screenshot of the chat"* by default; *"✨ Screenshot ready — tap to generate"* when `detectedScreenshotID != nil`.
- Tapping the armed strip calls `model.generateFromScreenshot()`.

### State added to `KeyboardModel`
- `@Published var detectedScreenshotID: String? = nil` — the localIdentifier of a newly-detected screenshot awaiting the confirm tap.

---

## Permission (Phase 1)

Uses the Photos grant already wired during the spike (dev-screen "Request Photos Access"). **The spike's `NSPhotoLibraryUsageDescription` fix stays.** Proper onboarding permission UX is Phase 2. If Photos isn't authorized, the strip shows *"Allow Photos in Settings to capture"* and does nothing destructive.

---

## What is explicitly NOT in Phase 1

- The slim-bar-as-default-Chat-state redesign (replacing the idle panel) → **Phase 3**
- Onboarding restructure + Back Tap demotion → **Phase 2**
- Removing Back Tap / the Shortcut / `GenerateReplyIntent` → they keep working untouched; the new flow is additive
- Any change to the replies panel, tones, or email mode

---

## Reused vs new — summary

| Concern | Source |
|---|---|
| Collapse-to-strip UI | existing (`isCollapsed`) |
| API call + contact + memory + session save | existing `generateEmailReply()` pattern |
| Screenshot read (low-memory) | spike (`requestImageDataAndOrientation`) |
| Replies panel / insert | existing |
| Photos watch + baseline dedup | **new** (small) |
| `generateFromScreenshot()` | **new** (mirrors email) |
| `detectedScreenshotID` + strip copy/tap | **new** (small) |

---

## Success criteria

On device, with Photos granted: collapse the keyboard, take a screenshot of a chat, tap the armed strip → real replies for that chat appear in the keyboard, no Back Tap involved. Capture history shows the session with tone + cost. Unrelated screenshots taken while *not* collapsed do not trigger anything.
