# Companion App UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the companion app from four tabs to two — Settings (default) and History — folding Tones and Memory into those tabs and adding a user-controlled Memory enable toggle.

**Architecture:** `ContentView` drops to a two-tab `TabView` (Settings first, History second). `SettingsView` gains a Tones navigation row and a Memory enable toggle. `CaptureLogView` is renamed `HistoryView` and gains a sparkles indicator on contact chips plus a "View Memory" banner when a contact with memory is filtered. `SummariesView` is deleted; `ContactMemoryDetailView` is moved to its own file and pushed as a sheet from `HistoryView`. A new `memoryEnabled` flag in `AppGroupService` / `Constants` drives whether `GenerateReplyIntent` sends `previousContext` to the LLM.

**Tech Stack:** Swift 5.9, SwiftUI, UIKit (AppGroupService), iOS 16+, SF Symbols, XCTest (unit test for AppGroupService).

---

## File Map

| File | Action |
|------|--------|
| `Shared/Constants.swift` | Add `memoryEnabledKey` |
| `Shared/AppGroupService.swift` | Add `memoryEnabled: Bool` computed property |
| `Replr/Replr/Intents/GenerateReplyIntent.swift` | Guard `recentSummaries()` behind `memoryEnabled` |
| `Replr/Replr/Features/Settings/SettingsView.swift` | Add Memory toggle + Tones navigation row |
| `Replr/Replr/Features/Summaries/ContactMemoryDetailView.swift` | **Create** — extract from `SummariesView.swift` |
| `Replr/Replr/Features/Summaries/SummariesView.swift` | **Delete** |
| `Replr/Replr/Features/Summaries/SummaryDetailView.swift` | **Delete** (dead code, uses stale `ConversationSummary` type) |
| `Replr/Replr/Features/Captures/CaptureLogView.swift` | Rename structs → `HistoryView` / `HistoryViewModel`; add sparkles + memory banner |
| `Replr/Replr/App/ReplrApp.swift` — `ContentView` | Replace 4-tab with 2-tab (Settings, History) |

---

## Task 1: Add `memoryEnabled` to Constants and AppGroupService

**Files:**
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`

- [ ] **Step 1: Add the key constant**

In `Shared/Constants.swift`, add after `memoryDepthKey`:

```swift
static let memoryEnabledKey       = "memory_enabled"
```

- [ ] **Step 2: Add the computed property to AppGroupService**

In `Shared/AppGroupService.swift`, add after the `memoryDepth` property block (around line 315):

```swift
/// Whether memory context is fed to the LLM. Defaults to true.
var memoryEnabled: Bool {
    get { defaults.object(forKey: Constants.memoryEnabledKey) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Constants.memoryEnabledKey); defaults.synchronize() }
}
```

- [ ] **Step 3: Build to verify**

In Xcode: ⌘B on the `ReplrKeyboard` scheme.
Expected: `BUILD SUCCEEDED` (no errors).

- [ ] **Step 4: Commit**

```bash
git add Shared/Constants.swift Shared/AppGroupService.swift
git commit -m "feat: add memoryEnabled flag to AppGroupService"
```

---

## Task 2: Guard `recentSummaries()` in GenerateReplyIntent

**Files:**
- Modify: `Replr/Replr/Intents/GenerateReplyIntent.swift:36-42`

- [ ] **Step 1: Replace the previousContext block**

Replace lines 35–42 (the `previousContext` block) with:

```swift
// Feed memory context only when the user has enabled Memory
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

- [ ] **Step 2: Build to verify**

⌘B on `ReplrKeyboard` scheme.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add "Replr/Replr/Intents/GenerateReplyIntent.swift"
git commit -m "feat: skip memory context when memoryEnabled is false"
```

---

## Task 3: Update SettingsView — Memory toggle + Tones row

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Add `memoryEnabled` state**

Add after the existing `@State private var memoryDepth` line:

```swift
@State private var memoryEnabled = AppGroupService.shared.memoryEnabled
```

- [ ] **Step 2: Replace the Keyboard section to add the Tones row**

Replace the current Keyboard section:

```swift
Section {
    Toggle("Keep replies between sessions", isOn: $persistReplies)
        .onChange(of: persistReplies) { newValue in
            AppGroupService.shared.persistReplies = newValue
        }
} header: {
    Text("Keyboard")
} footer: {
    Text("When enabled, your last generated replies stay visible the next time you open the keyboard.")
}
```

With:

```swift
Section {
    NavigationLink(destination: TonesView()) {
        Text("Tones")
    }
    Toggle("Keep replies between sessions", isOn: $persistReplies)
        .onChange(of: persistReplies) { newValue in
            AppGroupService.shared.persistReplies = newValue
        }
} header: {
    Text("Keyboard")
} footer: {
    Text("When enabled, your last generated replies stay visible the next time you open the keyboard.")
}
```

- [ ] **Step 3: Replace the Memory section to add the toggle and conditional pickers**

Replace the current Memory section:

```swift
Section {
    Picker("Time window", selection: $memoryWindowDays) {
        Text("7 days").tag(7)
        Text("30 days").tag(30)
        Text("90 days").tag(90)
        Text("All time").tag(0)
    }
    .onChange(of: memoryWindowDays) { AppGroupService.shared.memoryWindowDays = $0 }

    Picker("Conversations per contact", selection: $memoryDepth) {
        Text("5").tag(5)
        Text("10").tag(10)
        Text("20").tag(20)
    }
    .onChange(of: memoryDepth) { AppGroupService.shared.memoryDepth = $0 }
} header: {
    Text("Memory")
} footer: {
    Text("How far back Replr looks when building context for each contact. Maximum 20 past conversations.")
}
```

With:

```swift
Section {
    Toggle("Enable Memory", isOn: $memoryEnabled)
        .onChange(of: memoryEnabled) { AppGroupService.shared.memoryEnabled = $0 }
    if memoryEnabled {
        Picker("Time window", selection: $memoryWindowDays) {
            Text("7 days").tag(7)
            Text("30 days").tag(30)
            Text("90 days").tag(90)
            Text("All time").tag(0)
        }
        .onChange(of: memoryWindowDays) { AppGroupService.shared.memoryWindowDays = $0 }

        Picker("Conversations per contact", selection: $memoryDepth) {
            Text("5").tag(5)
            Text("10").tag(10)
            Text("20").tag(20)
        }
        .onChange(of: memoryDepth) { AppGroupService.shared.memoryDepth = $0 }
    }
} header: {
    Text("Memory")
} footer: {
    Text("When enabled, Replr summarises each conversation and uses it as context when generating future replies for the same contact.")
}
```

- [ ] **Step 4: Build to verify**

⌘B on `ReplrKeyboard` scheme.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add "Replr/Replr/Features/Settings/SettingsView.swift"
git commit -m "feat: settings — memory enable toggle + tones navigation row"
```

---

## Task 4: Extract ContactMemoryDetailView, delete dead files

**Files:**
- Create: `Replr/Replr/Features/Summaries/ContactMemoryDetailView.swift`
- Delete: `Replr/Replr/Features/Summaries/SummariesView.swift`
- Delete: `Replr/Replr/Features/Summaries/SummaryDetailView.swift`

- [ ] **Step 1: Create ContactMemoryDetailView.swift**

Create `Replr/Replr/Features/Summaries/ContactMemoryDetailView.swift` with:

```swift
import SwiftUI

struct ContactMemoryDetailView: View {
    let contact: Contact
    var onClearMemory: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false

    private var sessions: [CaptureSession] {
        AppGroupService.shared.sessions(forContactID: contact.id)
            .filter { $0.llmSummary != nil }
            .reversed()
    }

    var body: some View {
        List {
            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 5) {
                    Text(formattedTimestamp(session.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let summary = session.llmSummary {
                        Text(summary)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button(role: .destructive) { showClearConfirm = true } label: {
                Text("Clear Memory")
            }
        }
        .confirmationDialog(
            "Clear all memory for \(contact.displayName)?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear Memory", role: .destructive) {
                onClearMemory()
                dismiss()
            }
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if cal.isDateInToday(date) { return "Today · \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday · \(time)" }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
```

- [ ] **Step 2: Remove SummariesView.swift and SummaryDetailView.swift from the Xcode project**

In Xcode's Project Navigator: right-click `SummariesView.swift` → Delete → Move to Trash.
Repeat for `SummaryDetailView.swift`.

Then add `ContactMemoryDetailView.swift` to the project if Xcode didn't auto-add it (drag into the Summaries group).

- [ ] **Step 3: Build to verify**

⌘B on `ReplrKeyboard` scheme.
Expected: `BUILD SUCCEEDED` with no "cannot find type" errors.

- [ ] **Step 4: Commit**

```bash
git add "Replr/Replr/Features/Summaries/ContactMemoryDetailView.swift"
git rm "Replr/Replr/Features/Summaries/SummariesView.swift"
git rm "Replr/Replr/Features/Summaries/SummaryDetailView.swift"
git commit -m "refactor: extract ContactMemoryDetailView, delete unused SummariesView"
```

---

## Task 5: Rename CaptureLogView → HistoryView, add sparkles + memory banner

**Files:**
- Modify: `Replr/Replr/Features/Captures/CaptureLogView.swift`

- [ ] **Step 1: Rename view and view-model, add state**

Replace the opening of the file through `CaptureLogViewModel` and `CaptureLogView`:

Find-replace in the file: `CaptureLogViewModel` → `HistoryViewModel`, `CaptureLogView` → `HistoryView`. (3 occurrences each — the struct declaration, the `@StateObject` line, and the `NavigationLink` destination in `CaptureLogView`.)

Add `@State private var memoryEnabled = AppGroupService.shared.memoryEnabled` and `@State private var memoryContact: Contact? = nil` to `HistoryView`:

```swift
struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var memoryContact: Contact? = nil
```

- [ ] **Step 2: Update the navigation title**

Change `.navigationTitle("Captures")` to `.navigationTitle("History")`.

- [ ] **Step 3: Add the memory helper**

Add this private method inside `HistoryView`, after `filterChip`:

```swift
private func contactHasMemory(id: UUID) -> Bool {
    AppGroupService.shared.sessions(forContactID: id).contains { $0.llmSummary != nil }
}
```

- [ ] **Step 4: Update filterChip to show sparkles**

Replace the existing `filterChip` function:

```swift
@ViewBuilder
private func filterChip(label: String, id: UUID?) -> some View {
    let isSelected = vm.selectedContactID == id
    let hasMemory = id.map { contactHasMemory(id: $0) } ?? false
    let showSparkles = hasMemory && memoryEnabled
    Button { vm.selectedContactID = id } label: {
        HStack(spacing: 4) {
            Text(label)
                .lineLimit(1)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            if showSparkles {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: 160)
        .background(isSelected ? Replr.accent : Color(.secondarySystemGroupedBackground))
        .foregroundStyle(isSelected ? Replr.accentFg : Color.primary)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 5: Add View Memory banner between chip row and list**

In `body`, inside the `if !vm.allContacts.isEmpty` block, after the existing `Divider()`:

```swift
if let id = vm.selectedContactID,
   memoryEnabled,
   let contact = vm.allContacts.first(where: { $0.id == id }),
   contactHasMemory(id: id) {
    Button { memoryContact = contact } label: {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
            Text("View Memory for \(contact.displayName)")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
        }
        .foregroundStyle(Replr.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Replr.accent.opacity(0.08))
    }
    .buttonStyle(.plain)
    Divider()
}
```

- [ ] **Step 6: Add sheet for memory detail**

Add to the `NavigationStack` (or the top-level `Group`) as a modifier:

```swift
.sheet(item: $memoryContact) { contact in
    NavigationStack {
        ContactMemoryDetailView(contact: contact, onClearMemory: {
            AppGroupService.shared.clearMemory(forContactID: contact.id)
            vm.load()
            memoryContact = nil
        })
    }
}
```

- [ ] **Step 7: Refresh memoryEnabled on appear**

Add to `.onAppear { vm.load() }`:

```swift
.onAppear {
    vm.load()
    memoryEnabled = AppGroupService.shared.memoryEnabled
}
```

- [ ] **Step 8: Build to verify**

⌘B on `ReplrKeyboard` scheme.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 9: Commit**

```bash
git add "Replr/Replr/Features/Captures/CaptureLogView.swift"
git commit -m "feat: rename CaptureLogView → HistoryView, add sparkles chip + memory banner"
```

---

## Task 6: Collapse ContentView to 2 tabs

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift` — `ContentView` struct

- [ ] **Step 1: Replace the TabView body**

Replace the entire `ContentView` struct:

```swift
struct ContentView: View {
    var body: some View {
        TabView {
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
        }
        .tint(Replr.accent)
        .preferredColorScheme(.dark)
        .task {
            let txID = await SubscriptionManager.shared.currentTransactionID()
            UserDefaults(suiteName: Constants.appGroupID)?.set(txID, forKey: "transaction_id")
        }
    }
}
```

- [ ] **Step 2: Build to verify**

⌘B on `ReplrKeyboard` scheme.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Run and verify manually**

Launch in simulator (iPhone 16, iOS 18):
- App opens to Settings tab by default ✓
- Settings shows Tones row in Keyboard section ✓
- Tapping Tones row navigates to tone manager ✓
- Memory section shows Enable Memory toggle ✓
- Toggle off hides Time window and Conversations pickers ✓
- History tab shows capture timeline ✓
- No Memory or Tones tabs exist ✓
- Captures with contacts show sparkles on chip when memory enabled ✓
- Filtering by a contact with memory shows "View Memory" banner ✓
- Tapping banner opens memory sheet ✓
- Clear Memory from sheet works ✓

- [ ] **Step 4: Commit**

```bash
git add "Replr/Replr/App/ReplrApp.swift"
git commit -m "feat: collapse companion app to 2 tabs — Settings + History"
```
