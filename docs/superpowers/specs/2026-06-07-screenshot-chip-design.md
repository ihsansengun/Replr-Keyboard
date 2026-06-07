# Screenshot Chip — Design Spec
_2026-06-07_

## Overview

Enhance Replr's native screenshot detection so the keyboard surfaces a "📸 Screenshot detected" chip whenever it opens after a recent screenshot was taken — even if the keyboard was closed at capture time. Back Tap remains fully intact as an optional, faster path.

---

## Goals

- Zero extra setup for the user (no Back Tap required)
- Works for any screenshot: chat, Tinder profile, Instagram story, anything
- One tap from chip → replies, matching the speed of Back Tap
- No interference with existing Back Tap or reply generation flows

---

## Non-Goals

- Image content classification (no attempt to detect if screenshot is "chat-like")
- Background monitoring while neither the keyboard nor companion app is open
- Replacing or demoting Back Tap

---

## Architecture

### New file: `ReplrKeyboard/Services/ScreenshotChipService.swift`

`@MainActor` class owned by `KeyboardModel`. Single responsibility: detect a fresh screenshot on keyboard activation and expose it for the chip UI.

**API:**
```swift
func activate()           // run one-shot PHFetch; start 30s timer if found
func dismiss()            // user tapped X — clear chip, cancel timer
func consume() -> PHAsset? // user tapped chip — clear chip, cancel timer, return asset
```

**Detection logic:**
- `PHFetchRequest` filtered to `mediaSubtype == .photoScreenshot` and `creationDate >= now - 5 minutes`
- Sorted by `creationDate` descending, limit 1
- Skips any asset whose `localIdentifier` matches `AppGroupService.lastConsumedScreenshotID`
- Silently no-ops if `PHAuthorizationStatus` is not `.authorized` or `.limited`

**Published output:**
```swift
@Published var detectedAsset: PHAsset? = nil
```

### `KeyboardModel` changes

- Add `@Published var pendingScreenshotChip: PHAsset? = nil`
- Add `private let screenshotChipService = ScreenshotChipService()`
- On `keyboardDidAppear()` → call `screenshotChipService.activate()`; bind `detectedAsset` → `pendingScreenshotChip`
- `func useScreenshotChip()` → `consume()` → copy asset to App Group file → `state = .loading` → fire `GenerateReplyIntent`
- `func dismissScreenshotChip()` → `dismiss()` → `pendingScreenshotChip = nil`

**No new `KeyboardState` case.** The chip is an overlay on `.idle`, not a new state — same pattern as the undo chip in `ReplrStrip`.

### `AppGroupService` changes

- New key `lastConsumedScreenshotID: String?` (UserDefaults)
- Written by `KeyboardModel.useScreenshotChip()` after consuming the asset

### `KeyboardViewController` changes

- Ensure `KeyboardModel.keyboardDidAppear()` is called from `viewDidAppear`

---

## Data Flow

### On keyboard appear
```
KeyboardViewController.viewDidAppear
  → KeyboardModel.keyboardDidAppear()
    → ScreenshotChipService.activate()
      → PHFetchRequest (screenshots, last 5 min, most recent, skip consumed ID)
      → found → pendingScreenshotChip = asset; start 30s timer
      → not found → no-op
```

### User taps chip
```
ReplrStrip chip tap
  → KeyboardModel.useScreenshotChip()
    → ScreenshotChipService.consume()       // clears chip, cancels timer
    → PHImageManager.requestImage(asset)    // full-size, requested only now
    → write JPEG → App Group screenshot.png
    → AppGroupService.lastConsumedScreenshotID = asset.localIdentifier
    → AppGroupService.clearReplies()
    → KeyboardModel.state = .loading
    → GenerateReplyIntent.perform()
```

### User taps X
```
ReplrStrip X tap
  → KeyboardModel.dismissScreenshotChip()
    → ScreenshotChipService.dismiss()
    → pendingScreenshotChip = nil
```

### 30-second timer fires
```
Timer fires → pendingScreenshotChip = nil   // silent auto-dismiss, no side effects
```

### Back Tap path
Unchanged. Writes to App Group and fires intent directly. `ScreenshotChipService` is never involved.

---

## UI Changes

### `ReplrStrip` — priority order (updated)
```
1. Undo chip (lastInsertedReply)          — unchanged, highest priority
2. 📸 Screenshot detected chip            — NEW, second priority
3. Normal idle / loading / error content  — unchanged
```

### Chip appearance
- **Label:** `"📸 Screenshot detected"`
- **Style:** outlined secondary capsule — same component already used in `ReplrStrip`
- **Trailing X button** → `dismissScreenshotChip()`
- **Tap body** → `useScreenshotChip()`
- No thumbnail preview
- Appears/disappears with `.easeIn` / `.easeOut` fade
- No keyboard height change

### Other views
`KeyboardView`, `RepliesPanelView`, `LoadingPanelView` — no changes.

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| Photos permission not granted | Silent no-op; chip never appears; Back Tap unaffected |
| Screenshot already consumed (same ID) | Skipped in fetch; chip does not reappear |
| Keyboard reopened within 5-min window (not consumed) | Chip surfaces again — correct |
| PHAsset deleted between detection and tap | `requestImage` fails silently; chip clears; keyboard stays `.idle` |
| Back Tap fires while chip is visible | Keyboard transitions to `.loading` normally; chip irrelevant at that point |
| `GenerateReplyIntent` fires mid-flight after keyboard dismissed | No change from current behaviour — intent runs in companion app, results wait in App Group |

---

## Testing

### Unit tests
- Chip published when recent screenshot exists
- Chip not published when no screenshot in window
- Chip not published when asset ID matches `lastConsumedScreenshotID`
- `dismiss()` clears chip and cancels timer
- `consume()` clears chip, returns asset, writes `lastConsumedScreenshotID`
- Timer fires after 30s → chip nil (use injectable clock)

### Manual device checklist
1. Screenshot while keyboard closed → open keyboard → chip appears
2. Wait 30s → chip auto-dismisses
3. Tap chip → `.loading` → replies appear
4. Screenshot → open keyboard → tap X → chip gone, idle remains
5. Use chip → reopen keyboard within 5 min → chip does NOT reappear
6. Back Tap fires while chip showing → no interference
7. No screenshot in last 5 min → open keyboard → no chip appears
