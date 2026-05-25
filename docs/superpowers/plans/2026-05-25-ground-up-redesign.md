# Replr Ground-Up Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the ground-up redesign: 3-tab companion app (Replies / Memory / Settings), Memory as a first-class tab, PrivacyView in Settings, rebuilt onboarding (4 steps + skip path at Back Tap), keyboard expanded to 400px for the replies state with a stacked reply list, memory cue in keyboard, tones cut from 7 to 4, and a one-time first-capture consent overlay in the keyboard.

**Architecture:** All cross-process state flows through `AppGroupService` (App Group UserDefaults). New keys are added to `Constants.swift` first, new service properties second, then UI layers on top. The keyboard extension and companion app share state exclusively via the App Group — no new dependencies introduced.

**Tech Stack:** SwiftUI, UIKit (keyboard extension), AppIntents, UserDefaults (App Group), Combine.

---

## ⚠️ Prerequisite: New iCloud Shortcut (manual, before Task 11 ships)

The current onboarding shortcut (`https://www.icloud.com/shortcuts/4239b04c8d0d469b905ce6118c5ce706`) uses the wrong flow: it saves the screenshot to Photos and opens a manual picker in the companion app. The correct flow is **Take Screenshot → Generate Reply** (screenshot piped directly into `GenerateReplyIntent` via `connectToPreviousIntentResult`).

Before Task 11 ships, manually create a new iCloud shortcut:
1. New shortcut → "Take Screenshot" action
2. "Generate Reply" action (Replr) — the screenshot pipes in automatically
3. Set to run without confirmation, without notification banner
4. Share to iCloud → copy the link
5. Update `Constants.shortcutInstallURL` in Task 1 with the real link

Until this is done the install button in onboarding will open a broken URL. All other tasks are independent and can ship first.

---

## File Map

**New files:**
- `Replr/Replr/Features/Memory/MemoryView.swift`
- `Replr/Replr/Features/Settings/PrivacyView.swift`

**Modified files:**
- `Shared/Constants.swift` — 6 new keys
- `Shared/AppGroupService.swift` — 5 new properties, 1 migration fix
- `Shared/Models/Tone.swift` — 7 presets → 4
- `Replr/Replr/App/ReplrApp.swift` — ContentView 2 tabs → 3 tabs
- `Replr/Replr/Features/Captures/CaptureLogView.swift` — rename HistoryView → RepliesView, "Finish setup" banner
- `Replr/Replr/Features/Onboarding/OnboardingView.swift` — remove Photos step, 5→4 steps, auto-detect, skip path, privacy promise on Welcome
- `Replr/Replr/Features/Settings/SettingsView.swift` — Privacy link, tagline update
- `Replr/Replr/Features/Tones/TonesView.swift` — Dating as suggested custom tone
- `Replr/Replr/Intents/GenerateReplyIntent.swift` — write memoryUsedContactName when memory is used
- `Replr/Replr/Intents/ReplyTone.swift` — 7 cases → 4
- `Replr/Replr/AnalyzeScreenshotIntent.swift` — gut `perform()` body
- `Replr/Replr/AppShortcutsProvider.swift` — remove AnalyzeScreenshotIntent from shortcuts list
- `ReplrKeyboard/KeyboardViewController.swift` — write detection flags in viewDidLoad; expand .replies height to 400px; read memoryUsedContactName when replies arrive; set showConsentPrompt
- `ReplrKeyboard/Views/KeyboardView.swift` — add `memoryContactName` and `showConsentPrompt` to KeyboardModel
- `ReplrKeyboard/Views/RepliesPanelView.swift` — add memory cue row, first-capture consent overlay, stacked reply list replacing carousel

---

## Tasks

---

### Task 1: Add new Constants keys

**Files:**
- Modify: `Shared/Constants.swift`

- [ ] **Step 1: Add 6 new keys** — open `Shared/Constants.swift` and add after the `coachmarkSeenKey` line:

```swift
static let keyboardInstalledKey       = "keyboard_installed"
static let fullAccessGrantedKey       = "full_access_granted"
static let memoryUsedContactKey       = "memory_used_contact"
static let hasConsentedToCaptureKey   = "has_consented_to_capture"
static let backTapSkippedKey          = "back_tap_skipped"
// Update this URL once the new shortcut (Take Screenshot → Generate Reply) is created:
static let shortcutInstallURL         = "https://www.icloud.com/shortcuts/REPLACE_WITH_NEW_URL"
```

- [ ] **Step 2: Build** — ⌘B on the Replr scheme. Expect zero errors.

- [ ] **Step 3: Commit**

```bash
git add Shared/Constants.swift
git commit -m "feat: add constants for keyboard detection, memory cue, consent, back-tap-skipped, shortcut URL"
```

---

### Task 2: Add AppGroupService properties and tone migration

**Files:**
- Modify: `Shared/AppGroupService.swift`

- [ ] **Step 1: Add 5 new computed properties** — after the `isGenerating` property block (around line 72), insert:

```swift
// MARK: - Setup detection flags (written by keyboard extension, read by companion onboarding)

var keyboardInstalled: Bool {
    get { defaults.bool(forKey: Constants.keyboardInstalledKey) }
    set { defaults.set(newValue, forKey: Constants.keyboardInstalledKey); defaults.synchronize() }
}

var fullAccessGranted: Bool {
    get { defaults.bool(forKey: Constants.fullAccessGrantedKey) }
    set { defaults.set(newValue, forKey: Constants.fullAccessGrantedKey); defaults.synchronize() }
}

// MARK: - Memory cue (written by GenerateReplyIntent, read + consumed by keyboard)

var memoryUsedContactName: String? {
    get { defaults.string(forKey: Constants.memoryUsedContactKey) }
    set {
        if let v = newValue { defaults.set(v, forKey: Constants.memoryUsedContactKey) }
        else { defaults.removeObject(forKey: Constants.memoryUsedContactKey) }
        defaults.synchronize()
    }
}

// MARK: - First-capture consent (set once by keyboard after user acknowledges)

var hasConsentedToCapture: Bool {
    get { defaults.bool(forKey: Constants.hasConsentedToCaptureKey) }
    set { defaults.set(newValue, forKey: Constants.hasConsentedToCaptureKey); defaults.synchronize() }
}

// MARK: - Back Tap skipped during onboarding

var backTapSkipped: Bool {
    get { defaults.bool(forKey: Constants.backTapSkippedKey) }
    set { defaults.set(newValue, forKey: Constants.backTapSkippedKey); defaults.synchronize() }
}
```

- [ ] **Step 2: Add stale-tone migration to readSelectedTone()** — the function currently ends with `return tone`. Replace that last line so the function reads:

```swift
func readSelectedTone() -> Tone {
    defaults.synchronize()
    guard let data = defaults.data(forKey: Constants.selectedToneKey),
          let tone = try? JSONDecoder().decode(Tone.self, from: data) else {
        return readTones().first ?? Tone.presets[0]
    }
    // If the stored tone is a preset whose name no longer exists (e.g. Casual, Formal, Bold, Dating),
    // fall back to the first current preset so the user never sees a dangling tone name.
    let validPresetNames = Set(Tone.presets.map(\.name))
    if tone.isPreset && !validPresetNames.contains(tone.name) {
        return Tone.presets[0]
    }
    return tone
}
```

- [ ] **Step 3: Build** — ⌘B. Expect zero errors.

- [ ] **Step 4: Commit**

```bash
git add Shared/AppGroupService.swift
git commit -m "feat: add AppGroupService properties for keyboard detection, memory cue, consent, back-tap-skipped; fix stale-tone migration"
```

---

### Task 3: Cut Tone presets from 7 to 4

**Files:**
- Modify: `Shared/Models/Tone.swift`
- Modify: `Replr/Replr/Intents/ReplyTone.swift`

- [ ] **Step 1: Replace Tone.presets** — replace the entire contents of `Shared/Models/Tone.swift`:

```swift
import Foundation

struct Tone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instruction: String
    var isPreset: Bool

    static let presets: [Tone] = [
        Tone(id: UUID(), name: "Friendly",     instruction: "Warm, positive, and genuine. Light energy without being over-the-top.", isPreset: true),
        Tone(id: UUID(), name: "Professional", instruction: "Clear, competent, respectful. Formal but not stiff.", isPreset: true),
        Tone(id: UUID(), name: "Direct",       instruction: "Short, direct, punchy. No filler. Gets to the point.", isPreset: true),
        Tone(id: UUID(), name: "Witty",        instruction: "Smart and playful. A touch of dry humor. Never forced.", isPreset: true),
    ]
}
```

- [ ] **Step 2: Replace ReplyTone.swift** — replace the entire contents of `Replr/Replr/Intents/ReplyTone.swift`:

```swift
import AppIntents

enum ReplyTone: String, AppEnum {
    case friendly     = "Friendly"
    case professional = "Professional"
    case direct       = "Direct"
    case witty        = "Witty"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tone"
    static var caseDisplayRepresentations: [ReplyTone: DisplayRepresentation] = [
        .friendly:     "Friendly",
        .professional: "Professional",
        .direct:       "Direct",
        .witty:        "Witty",
    ]

    var tone: Tone {
        Tone.presets.first { $0.name == rawValue } ?? Tone.presets[0]
    }
}
```

- [ ] **Step 3: Fix the @Parameter default in GenerateReplyIntent** — open `Replr/Replr/Intents/GenerateReplyIntent.swift` and change:

```swift
@Parameter(title: "Tone", default: .casual)
```
to:
```swift
@Parameter(title: "Tone", default: .friendly)
```

- [ ] **Step 4: Build** — ⌘B. Fix any "no member 'casual'" or similar errors.

- [ ] **Step 5: Commit**

```bash
git add Shared/Models/Tone.swift Replr/Replr/Intents/ReplyTone.swift Replr/Replr/Intents/GenerateReplyIntent.swift
git commit -m "feat: cut tone presets to 4 (Friendly / Professional / Direct / Witty), update ReplyTone enum"
```

---

### Task 4: Suggest Dating as a custom tone in TonesView

**Files:**
- Modify: `Replr/Replr/Features/Tones/TonesView.swift`

- [ ] **Step 1: Read the file** — open and read `Replr/Replr/Features/Tones/TonesView.swift` to understand the current List/Form structure and the ViewModel's API (look for the method that adds a custom tone).

- [ ] **Step 2: Add a "Suggested" section** — find the section that lists custom tones. Above or below it (depending on the layout), add a new section that only shows when no custom tone named "Dating" already exists. Inside the existing `Form` or `List`, insert:

```swift
let hasDating = vm.customTones.contains { $0.name.lowercased() == "dating" }
if !hasDating {
    Section("Suggested") {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Dating")
                    .font(.body)
                Text("Confident and genuine. Light wit when it fits. Never desperate, never try-hard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            Spacer()
            Button("Add") {
                let dating = Tone(
                    id: UUID(),
                    name: "Dating",
                    instruction: "Confident and genuine. Light wit when it fits. Never desperate, never try-hard.",
                    isPreset: false
                )
                vm.add(dating)   // use whatever the ViewModel's add method is called
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(ReplrTheme.Color.accent)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
```

Adjust `vm.add(dating)` to match the actual ViewModel method name (may be `addCustomTone`, `addTone`, etc. — read the file first).

- [ ] **Step 3: Build** — ⌘B. Fix any compile errors.

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/Features/Tones/TonesView.swift
git commit -m "feat: suggest Dating as a custom tone in TonesView"
```

---

### Task 5: Create PrivacyView

**Files:**
- Create: `Replr/Replr/Features/Settings/PrivacyView.swift`

- [ ] **Step 1: Create the file** with this content:

```swift
import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What happens when you capture a chat")
                        .font(.headline)
                    Text("When you trigger a capture, the screenshot is sent from your device to Replr's server. The server calls an AI provider (Claude or GPT-4o) to write the replies. The screenshot is not stored on any server after the replies are returned.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What stays on your device")
                        .font(.headline)
                    Text("After each capture, a one-line summary of the conversation is saved on your device — in the app's private storage — for the memory feature. This summary is never sent to any server. It is only used as context for future replies with the same contact.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    Text("You can view and delete every summary Replr holds in the Memory tab.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your photo library")
                        .font(.headline)
                    Text("Replr's primary capture method (Back Tap → Shortcut) never accesses your photo library. The screenshot is passed directly to Replr in memory and is never saved to Photos.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Full Access")
                        .font(.headline)
                    Text("Replr requires Full Access for the keyboard extension. This lets the keyboard communicate with the companion app through a private shared storage area on your device. It does not grant access to anything you type in other apps.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Add the file to the Xcode project** — in Xcode's project navigator, right-click `Features/Settings` → "Add Files to 'Replr'" → select `PrivacyView.swift` → confirm target `Replr` is checked.

- [ ] **Step 3: Build** — ⌘B.

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/Features/Settings/PrivacyView.swift
git commit -m "feat: add PrivacyView with plain data-flow statement"
```

---

### Task 6: Update SettingsView — Privacy link + tagline

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Update the app description subtitle** — find:

```swift
Text("AI-powered reply keyboard")
    .font(.subheadline)
    .foregroundStyle(.secondary)
```

Replace with:

```swift
Text("Know what to say.")
    .font(.subheadline)
    .foregroundStyle(.secondary)
```

- [ ] **Step 2: Add a Privacy link to the About section** — find:

```swift
Section("About") {
    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
}
```

Replace with:

```swift
Section("About") {
    NavigationLink(destination: PrivacyView()) {
        Label("Privacy", systemImage: "lock.shield")
    }
    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
}
```

- [ ] **Step 3: Build** — ⌘B.

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/Features/Settings/SettingsView.swift
git commit -m "feat: add Privacy link to Settings, update tagline to 'Know what to say.'"
```

---

### Task 7: Create MemoryView

**Files:**
- Create: `Replr/Replr/Features/Memory/MemoryView.swift`

- [ ] **Step 1: Create the directory** (if it doesn't exist):

```bash
mkdir -p "/Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr/Features/Memory"
```

- [ ] **Step 2: Create MemoryView.swift** with this content:

```swift
import SwiftUI

final class MemoryViewModel: ObservableObject {
    @Published var contacts: [Contact] = []

    func load() {
        let sessions = AppGroupService.shared.loadCaptureSessions()
        let idsWithMemory = Set(sessions.compactMap { s -> UUID? in
            guard s.llmSummary != nil, let id = s.contactID else { return nil }
            return id
        })
        contacts = AppGroupService.shared.loadContacts()
            .filter { idsWithMemory.contains($0.id) }
    }

    func summaryCount(for contact: Contact) -> Int {
        AppGroupService.shared.sessions(forContactID: contact.id)
            .filter { $0.llmSummary != nil }
            .count
    }

    func clearMemory(for contact: Contact) {
        AppGroupService.shared.clearMemory(forContactID: contact.id)
        load()
    }

    func clearAll() {
        for contact in contacts {
            AppGroupService.shared.clearMemory(forContactID: contact.id)
        }
        contacts = []
    }
}

struct MemoryView: View {
    @StateObject private var vm = MemoryViewModel()
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled

    var body: some View {
        NavigationStack {
            Group {
                if vm.contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "brain")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No memory yet")
                            .font(.headline)
                        Text("Replr builds memory as you generate replies. Each contact gets a summary of your conversation history.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !memoryEnabled {
                            Section {
                                Label(
                                    "Memory is off. Enable it in Settings → Memory to use past context in future replies.",
                                    systemImage: "exclamationmark.triangle"
                                )
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            }
                        }

                        Section {
                            ForEach(vm.contacts) { contact in
                                NavigationLink(
                                    destination: ContactMemoryDetailView(
                                        contact: contact,
                                        onClearMemory: { vm.clearMemory(for: contact) }
                                    )
                                ) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(contact.displayName)
                                                .font(.body.weight(.medium))
                                            let count = vm.summaryCount(for: contact)
                                            Text("\(count) conversation\(count == 1 ? "" : "s") remembered")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12))
                                            .foregroundStyle(ReplrTheme.Color.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !vm.contacts.isEmpty {
                    Menu {
                        Button(role: .destructive) { vm.clearAll() } label: {
                            Label("Clear All Memory", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            vm.load()
            memoryEnabled = AppGroupService.shared.memoryEnabled
        }
    }
}
```

- [ ] **Step 3: Add the file to the Xcode project** — in Xcode's project navigator, right-click `Features` → "Add Files to 'Replr'" → select `Memory/MemoryView.swift` → confirm target `Replr` is checked.

- [ ] **Step 4: Build** — ⌘B.

- [ ] **Step 5: Commit**

```bash
git add "Replr/Replr/Features/Memory/MemoryView.swift"
git commit -m "feat: MemoryView — first-class tab showing contacts with memory, links to ContactMemoryDetailView"
```

---

### Task 8: 3-tab ContentView + rename HistoryView → RepliesView

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift`
- Modify: `Replr/Replr/Features/Captures/CaptureLogView.swift`

- [ ] **Step 1: Update ContentView** — in `ReplrApp.swift`, replace the ContentView body:

```swift
struct ContentView: View {
    var body: some View {
        TabView {
            RepliesView()
                .tabItem { Label("Replies", systemImage: "clock") }
            MemoryView()
                .tabItem { Label("Memory", systemImage: "brain") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(ReplrTheme.Color.accent)
        .task {
            let txID = await SubscriptionManager.shared.currentTransactionID()
            UserDefaults(suiteName: Constants.appGroupID)?.set(txID, forKey: "transaction_id")
        }
    }
}
```

- [ ] **Step 2: Rename in CaptureLogView.swift** — make these three changes:
  1. `final class HistoryViewModel` → `final class RepliesViewModel`
  2. `struct HistoryView` → `struct RepliesView` (update the `@StateObject var vm = HistoryViewModel()` line to `RepliesViewModel()`)
  3. `.navigationTitle("History")` → `.navigationTitle("Replies")`

- [ ] **Step 3: Build** — ⌘B. Fix any remaining `HistoryView` references.

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/App/ReplrApp.swift "Replr/Replr/Features/Captures/CaptureLogView.swift"
git commit -m "feat: 3-tab IA (Replies / Memory / Settings), rename HistoryView → RepliesView"
```

---

### Task 9: Remove AnalyzeScreenshotIntent from shortcuts

**Files:**
- Modify: `Replr/Replr/AnalyzeScreenshotIntent.swift`
- Modify: `Replr/Replr/AppShortcutsProvider.swift`

- [ ] **Step 1: Read both files** to understand their structure:

```bash
cat "Replr/Replr/AnalyzeScreenshotIntent.swift"
cat "Replr/Replr/AppShortcutsProvider.swift"
```

- [ ] **Step 2: Gut AnalyzeScreenshotIntent** — keep the struct declaration and all `@Parameter` properties (so the intent registration doesn't break), but replace the `perform()` body with an immediate return:

```swift
func perform() async throws -> some IntentResult {
    return .result()
}
```

- [ ] **Step 3: Remove AnalyzeScreenshotIntent from AppShortcutsProvider** — find the `appShortcuts` array and delete the entry that references `AnalyzeScreenshotIntent`. Keep all other entries unchanged.

- [ ] **Step 4: Build** — ⌘B.

- [ ] **Step 5: Commit**

```bash
git add "Replr/Replr/AnalyzeScreenshotIntent.swift" "Replr/Replr/AppShortcutsProvider.swift"
git commit -m "feat: gut AnalyzeScreenshotIntent and remove from app shortcuts (superseded by GenerateReplyIntent)"
```

---

### Task 10: Keyboard writes detection flags on load

The keyboard extension can only write to the App Group when Full Access is granted. So: `keyboardInstalled` is only writable with Full Access (which serves as combined proof of both). The companion app onboarding reads these flags to auto-detect setup completion.

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Add detection writes at the top of viewDidLoad** — immediately after `super.viewDidLoad()`, before the `heightConstraint` setup:

```swift
// Write setup-detection flags for onboarding. keyboardInstalled requires Full Access
// to write to the App Group — which also proves Full Access is granted.
if hasFullAccess {
    AppGroupService.shared.keyboardInstalled = true
    AppGroupService.shared.fullAccessGranted = true
}
```

- [ ] **Step 2: Build the ReplrKeyboard scheme** — select the ReplrKeyboard target → ⌘B.

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: keyboard writes keyboardInstalled + fullAccessGranted flags on load for onboarding auto-detection"
```

---

### Task 11: Rebuild OnboardingView — 4 steps, auto-detect, skip path, privacy promise

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

This is the largest task. New flow: Welcome (0) → Keyboard (1) → Full Access (2) → Shortcut (3) → Back Tap (4, with skip option).

- [ ] **Step 1: Add `import Combine` at the top** of OnboardingView.swift, and remove `import Photos`.

- [ ] **Step 2: Update WelcomeStep** — in `WelcomeStep.body`, add a privacy one-liner below the existing body text, inside the same `VStack(alignment: .leading, spacing: 16)`:

```swift
Text("Your conversations are sent to generate replies, then discarded — nothing stored on any server. See Privacy in Settings.")
    .font(.system(size: 12))
    .foregroundColor(ReplrTheme.Color.textTertiary)
    .lineSpacing(3)
    .fixedSize(horizontal: false, vertical: true)
```

- [ ] **Step 3: Replace AddKeyboardStep with auto-detection** — replace the entire `private struct AddKeyboardStep` with:

```swift
private struct AddKeyboardStep: View {
    let onNext: () -> Void
    @State private var detected = AppGroupService.shared.keyboardInstalled

    var body: some View {
        OnboardingStep(
            step: 1, totalSteps: 4,
            sectionLabel: "Keyboard",
            headline: "Add Replr to iOS.",
            bodyText: "The keyboard is where the replies show up. iOS will ask you to add it from Settings."
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(["Settings", "General", "Keyboard", "Keyboards"], id: \.self) { item in
                        if item != "Settings" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Text(item)
                            .font(.system(size: 12))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

                Divider().overlay(ReplrTheme.Color.border)

                HStack(spacing: 12) {
                    ReplrMark(size: 13)
                    Text("Replr")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Spacer()
                    if detected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ReplrTheme.Color.success)
                    }
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
                PrimaryButton(label: detected ? "Keyboard added ✓ — Continue →" : "Open Keyboard Settings →") {
                    if !detected, let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    onNext()
                }
                if !detected {
                    TertiaryButton(label: "Already added", action: onNext)
                }
            }
        }
        .onReceive(
            Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
        ) { _ in
            if !detected { detected = AppGroupService.shared.keyboardInstalled }
        }
    }
}
```

- [ ] **Step 4: Replace FullAccessStep with auto-detection** — replace the entire `private struct FullAccessStep` with:

```swift
private struct FullAccessStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var detected = AppGroupService.shared.fullAccessGranted

    var body: some View {
        OnboardingStep(
            step: 2, totalSteps: 4,
            sectionLabel: "Permissions",
            headline: "Enable Full Access.",
            bodyText: "Lets the keyboard connect to AI. Open Settings and follow the path below, then return here.",
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(["Settings", "General", "Keyboards", "Replr"], id: \.self) { item in
                        if item != "Settings" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Text(item)
                            .font(.system(size: 12))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

                Divider().overlay(ReplrTheme.Color.border)

                HStack(spacing: 12) {
                    ReplrMark(size: 13)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Replr")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("Allow Full Access")
                            .font(.system(size: 11))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                    Spacer()
                    if detected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ReplrTheme.Color.success)
                    }
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
                PrimaryButton(label: detected ? "Full Access enabled ✓ — Continue →" : "Open Keyboard Settings →") {
                    if !detected, let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    if detected { onNext() }
                }
                TertiaryButton(label: "Done →", action: onNext)
            }
        }
        .onReceive(
            Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
        ) { _ in
            if !detected { detected = AppGroupService.shared.fullAccessGranted }
        }
    }
}
```

- [ ] **Step 5: Replace InstallShortcutStep** — update the step number, totalSteps, shortcut URL, and actions preview:

Replace the entire `private struct InstallShortcutStep` with:

```swift
private struct InstallShortcutStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 3, totalSteps: 4,
            sectionLabel: "Shortcut",
            headline: "Install the Shortcut.",
            bodyText: "A two-step recipe in iOS Shortcuts takes the screenshot and hands it to Replr — no Photos access needed.",
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
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
                        Text("2 actions")
                            .font(.system(size: 11))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().overlay(ReplrTheme.Color.border)

                VStack(spacing: 0) {
                    ForEach(Array(["Take Screenshot", "Generate Reply"].enumerated()), id: \.offset) { idx, action in
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
                        if idx < 1 {
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
                    if let url = URL(string: Constants.shortcutInstallURL) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Already installed →", action: onNext)
            }
        }
    }
}
```

- [ ] **Step 6: Replace BackTapStep with skip option** — replace the entire `private struct BackTapStep` with:

```swift
private struct BackTapStep: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 4, totalSteps: 4,
            sectionLabel: "Back Tap",
            headline: "Triple-tap = capture.",
            bodyText: "Wire triple-tap to \"Replr Capture\" in iOS Accessibility. This is a one-time setup — then it's one gesture, forever.",
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(["Accessibility", "Touch", "Back Tap", "Triple Tap"], id: \.self) { item in
                        if item != "Accessibility" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        let isLast = item == "Triple Tap"
                        Text(item)
                            .font(.system(size: 12, weight: isLast ? .semibold : .regular))
                            .foregroundColor(isLast ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().overlay(ReplrTheme.Color.border)

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
                        Text("Three taps on the back. Anywhere.")
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
            VStack(spacing: 10) {
                PrimaryButton(label: "Open Back Tap Settings →") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Done →", action: onNext)
                Button("Skip for now — use Shortcuts.app instead") { onSkip() }
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(ReplrTheme.Color.textTertiary)
                Text("You can set up Back Tap later from the Replies tab.")
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(ReplrTheme.Color.textTertiary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }
}
```

- [ ] **Step 7: Update the root OnboardingView coordinator** — replace the entire `struct OnboardingView`:

```swift
struct OnboardingView: View {
    var onComplete: () -> Void
    var onSignIn: () -> Void = {}
    @AppStorage("onboardingStep") private var step = 0

    var body: some View {
        Group {
            switch step {
            case 0:
                WelcomeStep(onNext: { step = 1 }, onSignIn: onSignIn)
            case 1:
                AddKeyboardStep(onNext: { step = 2 })
            case 2:
                FullAccessStep(onNext: { step = 3 }, onBack: { step = 1 })
            case 3:
                InstallShortcutStep(onNext: { step = 4 }, onBack: { step = 2 })
            case 4:
                BackTapStep(
                    onNext: { step = 0; onComplete() },
                    onSkip: {
                        AppGroupService.shared.backTapSkipped = true
                        step = 0
                        onComplete()
                    },
                    onBack: { step = 3 }
                )
            default:
                WelcomeStep(onNext: { step = 1 }, onSignIn: onSignIn)
            }
        }
        .onAppear {
            if step > 4 { step = 0 }
        }
    }
}
```

- [ ] **Step 8: Delete the PhotosPermissionStep struct** — remove the entire `private struct PhotosPermissionStep` block (it is no longer referenced).

- [ ] **Step 9: Build** — ⌘B. Fix any compile errors (likely leftover `Photos` references or step count mismatches in the `OnboardingStep` header).

- [ ] **Step 10: Commit**

```bash
git add "Replr/Replr/Features/Onboarding/OnboardingView.swift"
git commit -m "feat: rebuild onboarding — 4 steps, auto-detect keyboard/Full Access, skip path at Back Tap, privacy promise on Welcome"
```

---

### Task 12: "Finish setup" banner in RepliesView

When `backTapSkipped` is true, show a dismissible banner at the top of the Replies tab.

**Files:**
- Modify: `Replr/Replr/Features/Captures/CaptureLogView.swift`

- [ ] **Step 1: Add state variables to RepliesView** — at the top of `struct RepliesView`:

```swift
@State private var backTapSkipped = AppGroupService.shared.backTapSkipped
@State private var showSetupSheet = false
```

- [ ] **Step 2: Add the banner** — inside the `NavigationStack`, immediately before the existing `Group { ... }`:

```swift
if backTapSkipped {
    HStack(spacing: 12) {
        Image(systemName: "hand.tap")
            .font(.system(size: 16))
            .foregroundStyle(ReplrTheme.Color.accent)
        VStack(alignment: .leading, spacing: 2) {
            Text("Finish setup")
                .font(.system(size: 13, weight: .semibold))
            Text("Set up Back Tap for one-gesture capture")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Set up") { showSetupSheet = true }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ReplrTheme.Color.accent)
        Button {
            AppGroupService.shared.backTapSkipped = false
            backTapSkipped = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(ReplrTheme.Color.accentSubtle)
}
```

- [ ] **Step 3: Wire the setup sheet** — add `.sheet(isPresented: $showSetupSheet) { BackTapSetupFullView(isPresented: $showSetupSheet) }` to the `NavigationStack`.

- [ ] **Step 4: Update onAppear to refresh the flag** — add `backTapSkipped = AppGroupService.shared.backTapSkipped` inside the existing `.onAppear` block.

- [ ] **Step 5: Build** — ⌘B.

- [ ] **Step 6: Commit**

```bash
git add "Replr/Replr/Features/Captures/CaptureLogView.swift"
git commit -m "feat: 'Finish setup' banner in Replies tab when Back Tap was skipped during onboarding"
```

---

### Task 13: GenerateReplyIntent writes memory contact name

**Files:**
- Modify: `Replr/Replr/Intents/GenerateReplyIntent.swift`

- [ ] **Step 1: Write the contact name after building previousContext** — find this block in `perform()`:

```swift
let previousContext: String?
if AppGroupService.shared.memoryEnabled,
   let contactID = AppGroupService.shared.currentContactID {
    let summaries = AppGroupService.shared.recentSummaries(
        forContactID: contactID,
        limit: AppGroupService.shared.memoryDepth
    )
    previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
} else {
    previousContext = nil
}
```

Immediately after this block, add:

```swift
// Write memory cue: tell the keyboard which contact's memory was used.
if previousContext != nil,
   let contactID = AppGroupService.shared.currentContactID,
   let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == contactID }) {
    AppGroupService.shared.memoryUsedContactName = contact.displayName
} else {
    AppGroupService.shared.memoryUsedContactName = nil
}
```

- [ ] **Step 2: Build** — ⌘B.

- [ ] **Step 3: Commit**

```bash
git add "Replr/Replr/Intents/GenerateReplyIntent.swift"
git commit -m "feat: GenerateReplyIntent writes memoryUsedContactName to App Group when memory context is used"
```

---

### Task 14: Memory cue in KeyboardModel + RepliesPanelView

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`
- Modify: `ReplrKeyboard/KeyboardViewController.swift`
- Modify: `ReplrKeyboard/Views/RepliesPanelView.swift`

- [ ] **Step 1: Add `memoryContactName` to KeyboardModel** — in `KeyboardView.swift`, inside `final class KeyboardModel`, add after `@Published var isCollapsed`:

```swift
@Published var memoryContactName: String? = nil
```

- [ ] **Step 2: Read and consume memoryContactName in KeyboardViewController** — in `startCapturePoll()`, inside the `else if let replies = AppGroupService.shared.consumeReplies()` branch, after `AppGroupService.shared.synchronize()`, add before the `await MainActor.run` block:

```swift
let memoryContact = AppGroupService.shared.memoryUsedContactName
AppGroupService.shared.memoryUsedContactName = nil
```

Then inside the existing `await MainActor.run { }` block (before the `withAnimation` that sets state), add:

```swift
self.model.memoryContactName = memoryContact
```

- [ ] **Step 3: Add the memory cue row to RepliesPanelView** — in `RepliesPanelView.body`, after the contact header block (`if let name = model.contactName { ... }`), add:

```swift
if let memoryName = model.memoryContactName {
    HStack(spacing: 5) {
        Image(systemName: "sparkles")
            .font(.system(size: 9))
        Text("Remembering your last chat with \(memoryName)")
            .font(.system(size: 11))
            .lineLimit(1)
    }
    .foregroundStyle(ReplrTheme.Color.accent)
    .padding(.horizontal, 16)
    .padding(.vertical, 5)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(ReplrTheme.Color.accentSubtle)
    ReplrTheme.Color.border.frame(height: 0.5)
}
```

- [ ] **Step 4: Build the ReplrKeyboard scheme** — select ReplrKeyboard target → ⌘B.

- [ ] **Step 5: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift ReplrKeyboard/KeyboardViewController.swift ReplrKeyboard/Views/RepliesPanelView.swift
git commit -m "feat: memory cue 'Remembering your last chat with [name]' in keyboard replies panel"
```

---

### Task 15: Expand keyboard height + stacked reply list

The replies state currently shows one reply at a time in an 88px carousel at 248px total height. This task expands to 400px and replaces the carousel with a vertically stacked selectable list.

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`
- Modify: `ReplrKeyboard/Views/RepliesPanelView.swift`

- [ ] **Step 1: Update the replies height** — in `KeyboardViewController`, in the `stateCancellable` sink's switch, change:

```swift
case .replies: height = 248
```
to:
```swift
case .replies: height = 400
```

- [ ] **Step 2: Replace carousel state with selectedIndex** — in `RepliesPanelView`, remove:

```swift
@State private var currentPage: Int = 0
```

Replace with:

```swift
@State private var selectedIndex: Int = 0
```

Update `currentReply` computed var:

```swift
private var currentReply: String {
    replies.indices.contains(selectedIndex) ? replies[selectedIndex] : replies.first ?? ""
}
```

- [ ] **Step 3: Replace the carousel + pageDots with a stacked reply list** — in `RepliesPanelView.body`, remove the `ReplyCarouselView(...)` call and its `.frame(height: 88)`, and remove the `pageDots` block. Replace them (keep everything else: mode control, contact header, action row) with:

```swift
ScrollView {
    VStack(spacing: 8) {
        ForEach(Array(replies.enumerated()), id: \.offset) { idx, reply in
            Button {
                selectedIndex = idx
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Text("\(idx + 1)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(
                            selectedIndex == idx
                                ? ReplrTheme.Color.onAccent
                                : ReplrTheme.Color.textTertiary
                        )
                        .frame(width: 18)
                    Text(reply)
                        .font(.system(size: 14))
                        .foregroundStyle(
                            selectedIndex == idx
                                ? ReplrTheme.Color.onAccent
                                : ReplrTheme.Color.textPrimary
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .fill(
                            selectedIndex == idx
                                ? ReplrTheme.Color.accent
                                : ReplrTheme.Color.surfaceRaised
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .stroke(
                            selectedIndex == idx ? Color.clear : ReplrTheme.Color.border,
                            lineWidth: 0.5
                        )
                )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.12), value: selectedIndex)
        }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
}
.frame(maxHeight: 240)
```

The `currentReply` (driven by `selectedIndex`) is already used in the action row's Insert button — no change needed there.

- [ ] **Step 4: Build the ReplrKeyboard scheme** — ⌘B.

- [ ] **Step 5: Check the LoadingPanelView text** — open `ReplrKeyboard/Views/LoadingPanelView.swift` and verify the loading message says something informative (e.g., "Reading this conversation…"). If it says something generic, update the text to match the brand voice.

- [ ] **Step 6: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift ReplrKeyboard/Views/RepliesPanelView.swift
git commit -m "feat: expand keyboard to 400px for replies state, replace carousel with stacked selectable reply list"
```

---

### Task 16: First-capture consent overlay in keyboard

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`
- Modify: `ReplrKeyboard/KeyboardViewController.swift`
- Modify: `ReplrKeyboard/Views/RepliesPanelView.swift`

- [ ] **Step 1: Add `showConsentPrompt` to KeyboardModel** — in `KeyboardView.swift`, add to KeyboardModel:

```swift
@Published var showConsentPrompt: Bool = false
```

- [ ] **Step 2: Set showConsentPrompt when replies arrive** — in `KeyboardViewController.startCapturePoll()`, inside the `else if let replies = ...` branch, after `self.model.memoryContactName = memoryContact`, add inside the `await MainActor.run { }` block:

```swift
if !AppGroupService.shared.hasConsentedToCapture {
    self.model.showConsentPrompt = true
}
```

- [ ] **Step 3: Add the consent overlay to RepliesPanelView** — at the very end of `RepliesPanelView.body`, add `.overlay` after `.background(ReplrTheme.Color.bg)`:

```swift
.overlay {
    if model.showConsentPrompt {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Before your first reply")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("Replr sent this screenshot to its server to generate these replies. The screenshot is not stored. Only a one-line summary stays on your device for the memory feature.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Button("Got it — show my replies") {
                    AppGroupService.shared.hasConsentedToCapture = true
                    model.showConsentPrompt = false
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(ReplrTheme.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.systemGray5))
            )
            .padding(.horizontal, 16)
        }
    }
}
```

- [ ] **Step 4: Build the ReplrKeyboard scheme** — ⌘B.

- [ ] **Step 5: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift ReplrKeyboard/KeyboardViewController.swift ReplrKeyboard/Views/RepliesPanelView.swift
git commit -m "feat: one-time first-capture consent overlay in keyboard before replies are usable"
```

---

## Self-Review

### Spec coverage

| Spec requirement | Task |
|---|---|
| Remove AnalyzeScreenshotIntent | Task 9 |
| Remove Photos from onboarding primary path | Task 11 (PhotosPermissionStep deleted) |
| Shortcut actions preview corrected (2 actions) | Task 11, Step 5 |
| Shortcut URL moved to Constants | Task 1, Task 11 |
| Rebuild onboarding, 4 steps | Task 11 |
| Auto-detect keyboard + Full Access | Task 10, 11 |
| "Skip for now" at Back Tap → backTapSkipped flag | Task 11, Step 6–7 |
| "Finish setup" banner in Replies tab | Task 12 |
| Memory as top-level tab | Task 7, 8 |
| PrivacyView in Settings | Task 5, 6 |
| Privacy promise on Welcome screen | Task 11, Step 2 |
| First-capture consent in keyboard | Task 16 |
| Memory cue in keyboard replies panel | Task 13, 14 |
| Keyboard expands to 400px for replies | Task 15 |
| Stacked reply list replaces carousel | Task 15 |
| Tones cut to 4 (Friendly/Professional/Direct/Witty) | Task 3 |
| Dating as suggested custom tone | Task 4 |
| Stale-tone migration (Casual/Formal/Bold/Dating → Friendly) | Task 2 |
| History → Replies rename | Task 8 |
| 3-tab ContentView | Task 8 |
| Tagline update ("Know what to say.") | Task 6 |

### Gaps

1. **LoadingPanelView text** — Task 15 Step 5 includes a manual check, but no code is prescribed because the file wasn't read. Verify: the loading panel should say "Reading this conversation…" or similar. If it shows a generic spinner only, add a `Text("Reading this conversation…")` below the progress view.

2. **Memory tab onboarding mention** — the spec says memory is introduced in onboarding as the reason replies get better over time. The current plan adds a privacy line to the Welcome screen but not an explicit memory pitch. Consider adding one sentence to the Welcome body: "Replr remembers past conversations so replies get better over time."

3. **iPhone SE height** — Task 15 sets replies height to 400px. On iPhone SE (667px total), 400px keyboard leaves only 267px for the conversation — potentially too tight. Run the ReplrKeyboard target on an iPhone SE simulator and reduce to 360px if the conversation area is unusable.

4. **Existing users who had Photos step completed** — users who already finished onboarding won't re-run it, so removing the Photos step has no migration risk. But the `onboardingStep` AppStorage key could be set to 3 or higher for existing installs — the new coordinator handles this correctly via `if step > 4 { step = 0 }`.

5. **Shortcut URL is a placeholder** — `Constants.shortcutInstallURL` contains `REPLACE_WITH_NEW_URL` until the real shortcut is created manually. The install button in onboarding will fail to open until this is updated. All other tasks are independent of this.
