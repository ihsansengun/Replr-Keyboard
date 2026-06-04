# Phase 0 Spike — Keyboard Photos Access & Memory — Design Spec

**Date:** 2026-06-04
**Status:** Awaiting user review
**Type:** Throwaway validation spike (go/no-go gate for the capture-bar feature)

---

## Why this spike exists

The proposed "capture bar" feature (Replr keyboard auto-detects a screenshot and generates replies with zero Shortcut/Back-Tap setup) rests on **one unproven assumption**: that the keyboard extension can read the latest screenshot from Photos *without exceeding its memory budget and crashing*.

Two hard facts make this uncertain, and neither can be settled by reading code:

1. **Keyboard extension memory ceiling is ~30–40 MB.** iOS jettisons the keyboard above it. Loading images is a documented crash cause. A decoded full-res screenshot is ~12 MB on its own.
2. **The app has no Photos permission infrastructure today.** No `NSPhotoLibraryUsageDescription`, no authorization request anywhere. `QuickReplyIntent` only checks status and bails. This is why the earlier "normal screenshot" attempt failed — there was no permission to read with.

This spike builds the minimum to answer: **can the keyboard see and read the latest screenshot, and how much memory headroom is left afterward?**

---

## Scope

**In scope (throwaway):**
- Photos permission infrastructure (usage string + an app-side request)
- A temporary keyboard "spike" button that reads the latest screenshot and reports memory headroom
- On-device measurement by the user

**Explicitly NOT in scope:**
- The capture bar UI, watching/polling loop, onboarding changes, Back Tap demotion — none of it. Those only get designed *after* this spike passes.
- The API call. We measure up to and including base64 encoding (the memory-heavy part); we do not hit the network.

---

## What gets built

### 1. Photos permission infrastructure (app process)

- Add `NSPhotoLibraryUsageDescription` to the **app** target's Info.plist. Without it, any Photos request crashes immediately.
  - String: `"Replr reads your most recent screenshot to generate reply suggestions. Screenshots are never stored."`
- Add a temporary button on the dev screen (`ModelPickerView`) that calls `PHPhotoLibrary.requestAuthorization(for: .readWrite)` and shows the resulting status. This is how the user grants the permission for the spike.

**Key assumption being tested:** Photos authorization is granted at the app-bundle level, and the embedded keyboard extension *inherits* it. The spike confirms this — if the keyboard sees `.authorized` after the app grants it, inheritance works.

### 2. Keyboard spike instrument (keyboard process)

A temporary button in the keyboard idle panel: **"🔬 Spike: read latest screenshot"**. On tap, in the keyboard process:

1. Log `PHPhotoLibrary.authorizationStatus(for: .readWrite)`.
2. Record memory headroom via `os_proc_available_memory()` (iOS 13+, returns bytes the process can still allocate before being killed).
3. Fetch the latest screenshot `PHAsset` (`PHFetchOptions`, predicate `mediaSubtype & photoScreenshot`, sort `creationDate` desc, `fetchLimit = 1`) — the same query `QuickReplyIntent` already uses.
4. Read raw bytes via `PHImageManager.default().requestImageDataAndOrientation(for:options:)` — **raw file data, no decode** (this is the memory-saving path vs. loading a `UIImage`).
5. Base64-encode the data (simulates upload prep — the real memory peak).
6. Record memory headroom again.
7. Surface the result **in the keyboard UI** (not just console, since the user is the one reading it): e.g. `"✓ read 2.9 MB · headroom 14 MB → 9 MB"` or, if it dies, the keyboard simply crashes/reloads — which is itself the answer.

### 3. Measurement method (user, on device)

1. Install on iPhone, enable Full Access for the Replr keyboard, tap the dev-screen button to grant Photos.
2. Take a screenshot of any chat.
3. Open the Replr keyboard, tap the spike button.
4. Report back: the on-screen result line (or "keyboard crashed").

---

## Go / No-Go criteria

| Outcome | Verdict | Next step |
|---|---|---|
| Reads screenshot, no crash, **headroom stays > ~10 MB** after base64 | ✅ GO | Write the full capture-bar feature spec |
| Reads but headroom is thin (< ~5 MB) or intermittent crashes | ⚠️ MARGINAL | Try streaming/chunked upload, or downscale via `requestImageData` with smaller target; re-measure |
| Keyboard crashes, or `authorizationStatus` never reaches `.authorized` from the extension | ❌ NO-GO | Pivot: move the read into the app process (Control Center control or Action Button → intent). Keeps the painless-onboarding win, drops full zero-tap. |

---

## APIs used (all verified present in iOS 13+ and consistent with existing `QuickReplyIntent` usage)

- `PHPhotoLibrary.requestAuthorization(for: .readWrite)` / `.authorizationStatus(for:)`
- `PHAsset.fetchAssets(with:options:)` + `PHAssetMediaSubtype.photoScreenshot`
- `PHImageManager.requestImageDataAndOrientation(for:options:resultHandler:)` — raw data, avoids decode
- `os_proc_available_memory()` — process memory headroom in bytes

## Cleanup

All spike code is marked `// SPIKE — remove after Phase 0` and stripped once measured, regardless of outcome. The `NSPhotoLibraryUsageDescription` and permission-request code stay **only if** the verdict is GO (they're needed by the real feature); otherwise they're reverted too.
