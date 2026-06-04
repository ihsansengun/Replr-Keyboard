# Keyboard Photos Spike — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove (or disprove) that the Replr keyboard extension can read the latest screenshot from Photos without exceeding its ~30–40 MB memory ceiling.

**Architecture:** Build the missing Photos permission infrastructure (fix the empty `NSPhotoLibraryUsageDescription` build settings + an app-side grant button), then add a throwaway keyboard instrument that reads the newest screenshot via `requestImageDataAndOrientation` (raw bytes, no decode) and reports memory headroom via `os_proc_available_memory()`. Verdict comes from a user running it on a physical device.

**Tech Stack:** SwiftUI, PhotoKit (`PHAsset`/`PHImageManager`), `os_proc_available_memory()` (os/proc.h), Xcode build settings.

**Note on TDD:** This is a validation spike. Its entire purpose is to measure runtime memory and PhotoKit behavior on a real device — there is no pure logic to unit-test, and the simulator reports the Mac's memory, not the device's jetsam limit. So verification per task is "compiles cleanly"; the **real** verification is the on-device measurement in the final task. All code is marked `// SPIKE — remove after Phase 0`.

---

## File Map

| File | Change |
|------|--------|
| `Replr/Replr.xcodeproj/project.pbxproj` | Set the 4 empty `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` values to a real string (app + keyboard, Debug + Release) |
| `ReplrKeyboard/PhotosSpike.swift` | **Create** — isolated spike helper that reads latest screenshot + measures memory |
| `ReplrKeyboard/Views/KeyboardView.swift` | Add `spikeResult` published property + `runPhotosSpike()` to `KeyboardModel` |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Add the spike button + result line to the chat idle panel |
| `Replr/Replr/Features/Settings/ModelPickerView.swift` | Add a "Request Photos Access" button to the dev screen |

---

## Task 1: Set the Photos usage string (fixes empty-string bug)

**Files:**
- Modify: `Replr/Replr.xcodeproj/project.pbxproj`

Context: The project sets `INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "";` (empty) in 4 build configs — app Debug, app Release, keyboard Debug, keyboard Release. An empty usage string means the Photos permission prompt has no text and iOS may suppress it or App Review may reject it. All 4 are identical, so one global replace fixes them.

- [ ] **Step 1: Replace all 4 empty usage strings** with a real one:

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
sed -i '' 's#INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "";#INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Replr reads your most recent screenshot to generate reply suggestions. Screenshots are never stored.";#g' Replr/Replr.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Verify all 4 were replaced** (expect `0` empty remaining, `4` filled):

```bash
echo "empty remaining: $(grep -c 'NSPhotoLibraryUsageDescription = "";' Replr/Replr.xcodeproj/project.pbxproj)"
echo "filled: $(grep -c 'NSPhotoLibraryUsageDescription = "Replr reads' Replr/Replr.xcodeproj/project.pbxproj)"
```
Expected: `empty remaining: 0` and `filled: 4`

- [ ] **Step 3: Build to confirm the project file still parses:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit:**

```bash
git add Replr/Replr.xcodeproj/project.pbxproj
git commit -m "fix: set NSPhotoLibraryUsageDescription (was empty in app + keyboard configs)"
```

---

## Task 2: Create the spike helper + model hooks

**Files:**
- Create: `ReplrKeyboard/PhotosSpike.swift`
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Context: `PhotosSpike.run()` does the actual work in the keyboard process. It is deliberately written to use `requestImageDataAndOrientation` (raw file bytes) rather than `requestImage` (decoded `UIImage`) — the decode is the memory spike we are trying to avoid. `KeyboardModel` gets a published result string so the UI can show it.

- [ ] **Step 1: Create `ReplrKeyboard/PhotosSpike.swift`:**

> **If the build fails with "cannot find 'os_proc_available_memory' in scope":** add `import os` below `import Photos`. The symbol lives in `os/proc.h`; it's normally exposed transitively via Foundation/Darwin, but `import os` guarantees it. Do not swap in a different memory API — `os_proc_available_memory()` (jetsam headroom in bytes) is specifically what we want to measure.

```swift
// SPIKE — remove after Phase 0. See docs/superpowers/specs/2026-06-04-keyboard-photos-spike-design.md
import Photos

enum PhotosSpike {
    /// Reads the latest screenshot from Photos and reports memory headroom.
    /// Returns a human-readable result line to show in the keyboard.
    static func run() async -> String {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return "✗ Photos not authorized (status=\(status.rawValue)). Grant in the app dev screen first."
        }

        let memBefore = os_proc_available_memory()

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 1
        opts.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        guard let asset = PHAsset.fetchAssets(with: .image, options: opts).firstObject else {
            return "✗ No screenshot found in Photos."
        }

        let data: Data? = await withCheckedContinuation { cont in
            let reqOpts = PHImageRequestOptions()
            reqOpts.isNetworkAccessAllowed = false
            reqOpts.isSynchronous = false
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: reqOpts) { data, _, _, _ in
                cont.resume(returning: data)
            }
        }

        guard let data else { return "✗ requestImageDataAndOrientation returned nil." }

        let memAfterRead = os_proc_available_memory()
        let base64 = data.base64EncodedString()
        let memAfterB64 = os_proc_available_memory()

        func mb(_ bytes: Int) -> String { String(format: "%.1f", Double(bytes) / 1_048_576) }
        return "✓ read \(mb(data.count))MB · b64 \(mb(base64.count)) · headroom \(mb(memBefore))→\(mb(memAfterRead))→\(mb(memAfterB64))MB"
    }
}
```

- [ ] **Step 2: Add the model hooks to `KeyboardModel`** in `ReplrKeyboard/Views/KeyboardView.swift`. Find the line `@Published var showConsentPrompt: Bool = false` and add directly after it:

```swift
    @Published var spikeResult: String? = nil  // SPIKE — remove after Phase 0
```

- [ ] **Step 3: Add the `runPhotosSpike()` method.** Find `func editReply(_ text: String) { onEditReply?(text) }` and add directly after it:

```swift
    // SPIKE — remove after Phase 0
    func runPhotosSpike() {
        spikeResult = "Running…"
        Task { @MainActor in
            let result = await PhotosSpike.run()
            spikeResult = result
            NSLog("[Replr][Spike] %@", result)
        }
    }
```

- [ ] **Step 4: Build:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit:**

```bash
git add ReplrKeyboard/PhotosSpike.swift ReplrKeyboard/Views/KeyboardView.swift
git commit -m "spike: add PhotosSpike helper + keyboard model hooks"
```

---

## Task 3: Add the spike button to the keyboard idle panel

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift`

Context: The chat idle panel (`chatContent`) renders a card ending around line 89 (`.elevatedSurface(.level1)`) inside an outer `VStack`. Add the spike button and result line just below that card, still inside the outer `VStack(alignment: .leading, spacing: 0)`.

- [ ] **Step 1: Insert the spike UI.** Find this block in `chatContent`:

```swift
            .elevatedSurface(.level1)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
```

Replace it with:

```swift
            .elevatedSurface(.level1)

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
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
```

- [ ] **Step 2: Build:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit:**

```bash
git add ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "spike: add read-screenshot button to keyboard idle panel"
```

---

## Task 4: Add the Photos-grant button to the dev screen

**Files:**
- Modify: `Replr/Replr/Features/Settings/ModelPickerView.swift`

Context: The dev screen (`ModelPickerView`, reached via long-press on the version label in Settings) is where the user grants Photos for the spike. The keyboard can't present the permission dialog; the app must. Photos auth is granted at the app-bundle level and the embedded keyboard inherits it — confirming that inheritance is part of what the spike validates.

- [ ] **Step 1: Add the Photos import.** At the top of the file, find `import SwiftUI` and add after it:

```swift
import Photos
```

- [ ] **Step 2: Add a status state var.** Find `@State private var totalCostUsd: Double = 0` and add directly before it:

```swift
    @State private var photosStatus: String = "\(PHPhotoLibrary.authorizationStatus(for: .readWrite).rawValue)"  // SPIKE — remove after Phase 0
```

- [ ] **Step 3: Add the grant section.** Find the `// MARK: Total API Cost` line and insert this new `Section` directly before it:

```swift
            // SPIKE — remove after Phase 0
            Section {
                Button("Request Photos Access") {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        DispatchQueue.main.async { photosStatus = "\(status.rawValue)" }
                    }
                }
                HStack {
                    Text("Auth status (raw)")
                    Spacer()
                    Text(photosStatus).foregroundStyle(ReplrTheme.Color.textSecondary)
                }
            } header: {
                Text("Photos Permission (spike)")
            } footer: {
                Text("raw values: 0=notDetermined 1=restricted 2=denied 3=authorized 4=limited")
                    .font(.caption)
            }

```

- [ ] **Step 4: Build:**

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit:**

```bash
git add Replr/Replr/Features/Settings/ModelPickerView.swift
git commit -m "spike: add Photos-grant button to dev screen"
```

---

## Task 5: On-device measurement (user-run)

**Files:** none — this is the actual experiment.

Context: Simulator is useless here — `os_proc_available_memory()` reports the Mac's memory, not the device jetsam limit, and the simulator may have no screenshots. This must run on a physical iPhone.

- [ ] **Step 1: Hand off to the user with these instructions:**

  1. In Xcode, select a **physical iPhone** as the run destination and Run (⌘R).
  2. In the Replr app: open **Settings → long-press the version label → dev screen → "Request Photos Access"** → tap **Allow**. Confirm status shows `3` (authorized) or `4` (limited).
  3. Enable the keyboard with Full Access if not already: Settings → General → Keyboard → Keyboards → add Replr → Allow Full Access.
  4. Open any app with a text field, take a **screenshot** of any chat, then switch to the Replr keyboard.
  5. On the keyboard's chat idle panel, tap **"🔬 Spike: read latest screenshot."**
  6. Report back the result line shown under the button (e.g. `✓ read 2.9MB · b64 3.9 · headroom 22.0→19.1→15.2MB`), **or** "the keyboard crashed/reloaded."

- [ ] **Step 2: Record the verdict** against the spec's go/no-go table:
  - Headroom stays **> ~10 MB** after base64, no crash → **GO**: proceed to write the full capture-bar feature spec.
  - Headroom **< ~5 MB** or intermittent crash → **MARGINAL**: try downscaled read / chunked upload, re-measure.
  - Crash, or status never reaches authorized from the keyboard → **NO-GO**: pivot the read into the app process (Control Center / Action Button → intent).

- [ ] **Step 3: Clean up based on verdict.**
  - **GO:** remove only the `// SPIKE` code (PhotosSpike.swift, the model hooks, the keyboard button, the dev-screen section). **Keep** the `NSPhotoLibraryUsageDescription` fix from Task 1 — the real feature needs it.
  - **NO-GO / pivot:** additionally revert Task 1 if the app-process pivot won't use Photos from the keyboard (it still will, so keep it).

```bash
# Cleanup commit (after stripping // SPIKE blocks)
git add -A
git commit -m "chore: remove Phase 0 spike instrumentation (verdict recorded in plan)"
```

---

## Verification checklist

- [ ] All 4 `NSPhotoLibraryUsageDescription` build settings hold the real string (0 empty remain)
- [ ] App builds clean for simulator (compile check) at every task
- [ ] On device: dev-screen grant button moves auth status to 3 or 4
- [ ] On device: keyboard spike button returns a result line (not a crash)
- [ ] Headroom numbers recorded and compared against the go/no-go thresholds
- [ ] Verdict written down; spike code removed; permission infra kept iff GO
