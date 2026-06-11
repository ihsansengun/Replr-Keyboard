# App Screens UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the companion app into Home / History / Settings per
`docs/superpowers/specs/2026-06-11-app-screens-ux-design.md` — new Home tab (setup,
credits, recent, personalize), Replies→History with a person header absorbing the
Memory tab, Settings regrouped into a stateful root with sub-screens.

**Architecture:** Pure client-side SwiftUI reorganization in the `Replr` app target.
All data comes from existing `AppGroupService` / `CreditsManager` state — no new App
Group keys, no backend work, no keyboard changes. New screens are added first (they
compile unused), History is reworked, and the tab switch happens last so every commit
builds green. Display logic that carries rules (day grouping, credits math, header
strings) lives in tiny pure enums covered by Swift Testing tests.

**Tech Stack:** SwiftUI, Swift Testing (`@Test`/`#expect`), `ReplrTheme` tokens only
(no hardcoded colors/fonts/spacing — see `DESIGN.md`), Xcode synchronized groups
(new files under `Replr/Replr/` and `Replr/ReplrTests/` join their targets
automatically).

**Build gate (run after every task, from the repo root):**

```bash
cd Replr && xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
```
Expected: `** BUILD SUCCEEDED **`. (SourceKit "No such module" noise in the editor is
a false positive; xcodebuild is the source of truth.)

**Test command (Tasks 1 and 10):**

```bash
cd Replr && xcodebuild test -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:ReplrTests
```
Expected: `** TEST SUCCEEDED **`. If the `Replr` scheme has no test action in your
checkout, run ⌘U in Xcode instead and paste the result.

---

### Task 1: Display-logic helpers + tests (TDD)

**Files:**
- Create: `Replr/Replr/Features/Captures/HistoryLogic.swift`
- Create: `Replr/Replr/Features/Home/HomeLogic.swift`
- Test: `Replr/ReplrTests/AppScreensLogicTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Replr/ReplrTests/AppScreensLogicTests.swift`:

```swift
import Testing
import Foundation
@testable import Replr

struct HistoryLogicTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }
    private let en = Locale(identifier: "en_US")
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(timeZone: cal.timeZone, year: y, month: m, day: d, hour: h))!
    }

    @Test func dayLabels() {
        let now = date(2026, 6, 11)
        #expect(HistoryLogic.dayLabel(for: date(2026, 6, 11, 9), now: now, calendar: cal, locale: en) == "Today")
        #expect(HistoryLogic.dayLabel(for: date(2026, 6, 10, 23), now: now, calendar: cal, locale: en) == "Yesterday")
        #expect(HistoryLogic.dayLabel(for: date(2026, 6, 9), now: now, calendar: cal, locale: en) == "Jun 9")
    }

    @Test func dayGroupsNewestDayFirstAndStableWithinDay() {
        let now = date(2026, 6, 11)
        // Input is newest-first, as HistoryView receives it.
        let items: [Date] = [date(2026, 6, 11, 15), date(2026, 6, 11, 9), date(2026, 6, 10, 22), date(2026, 6, 9, 8)]
        let groups = HistoryLogic.dayGroups(items, date: { $0 }, now: now, calendar: cal, locale: en)
        #expect(groups.map(\.label) == ["Today", "Yesterday", "Jun 9"])
        #expect(groups[0].items == [date(2026, 6, 11, 15), date(2026, 6, 11, 9)])
        #expect(groups[1].items == [date(2026, 6, 10, 22)])
        #expect(groups.map(\.day) == [cal.startOfDay(for: date(2026, 6, 11)),
                                      cal.startOfDay(for: date(2026, 6, 10)),
                                      cal.startOfDay(for: date(2026, 6, 9))])
    }

    @Test func dayLabelAppendsYearForOtherYears() {
        let now = date(2026, 6, 11)
        #expect(HistoryLogic.dayLabel(for: date(2025, 6, 9), now: now, calendar: cal, locale: en) == "Jun 9, 2025")
        #expect(HistoryLogic.dayLabel(for: date(2026, 6, 9), now: now, calendar: cal, locale: en) == "Jun 9")
    }

    @Test func dayLabelAcrossDSTBoundary() {
        // Europe/London springs forward on 29 Mar 2026.
        let now = date(2026, 3, 29)
        #expect(HistoryLogic.dayLabel(for: date(2026, 3, 28), now: now, calendar: cal, locale: en) == "Yesterday")
    }

    @Test func personSubtitles() {
        #expect(HistoryLogic.personSubtitle(replies: 5, remembered: 3) == "5 replies · 3 chats remembered")
        #expect(HistoryLogic.personSubtitle(replies: 1, remembered: 1) == "1 reply · 1 chat remembered")
        #expect(HistoryLogic.personSubtitle(replies: 4, remembered: 0) == "4 replies · nothing remembered yet")
    }
}

struct HomeLogicTests {
    @Test func approxReplies() {
        #expect(HomeLogic.approxReplies(balance: 84, costPerReply: 4) == 21)
        #expect(HomeLogic.approxReplies(balance: 3, costPerReply: 4) == 0)
        #expect(HomeLogic.approxReplies(balance: 0, costPerReply: 4) == 0)
        #expect(HomeLogic.approxReplies(balance: 10, costPerReply: 0) == 0)  // never divide by zero
    }

    @Test func lowBalance() {
        #expect(HomeLogic.isLowBalance(balance: 3, costPerReply: 4, devMode: false))
        #expect(!HomeLogic.isLowBalance(balance: 4, costPerReply: 4, devMode: false))
        #expect(!HomeLogic.isLowBalance(balance: 0, costPerReply: 4, devMode: true))  // dev mode never low
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test command from the header.
Expected: FAIL — `cannot find 'HistoryLogic' in scope`, `cannot find 'HomeLogic' in scope`.

- [ ] **Step 3: Implement the helpers**

Create `Replr/Replr/Features/Captures/HistoryLogic.swift`:

```swift
import Foundation

/// Pure display rules for the History tab. No UI, fully unit-tested.
enum HistoryLogic {
    /// "Today" / "Yesterday" / "Jun 9".
    static func dayLabel(for date: Date, now: Date = Date(),
                         calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated).day()
        if !calendar.isDate(date, equalTo: now, toGranularity: .year) {
            style = style.year()
        }
        return date.formatted(style)
    }

    /// Buckets newest-first items into day sections, newest day first.
    /// Order within a day is preserved from the input.
    static func dayGroups<T>(_ items: [T], date: (T) -> Date, now: Date = Date(),
                             calendar: Calendar = .current, locale: Locale = .current)
        -> [(day: Date, label: String, items: [T])] {
        let byDay = Dictionary(grouping: items) { calendar.startOfDay(for: date($0)) }
        return byDay.keys.sorted(by: >).map { day in
            (day: day,
             label: dayLabel(for: day, now: now, calendar: calendar, locale: locale),
             items: byDay[day] ?? [])
        }
    }

    /// "5 replies · 3 chats remembered" — the person-header subtitle.
    static func personSubtitle(replies: Int, remembered: Int) -> String {
        let r = "\(replies) \(replies == 1 ? "reply" : "replies")"
        guard remembered > 0 else { return "\(r) · nothing remembered yet" }
        return "\(r) · \(remembered) \(remembered == 1 ? "chat" : "chats") remembered"
    }
}
```

Create `Replr/Replr/Features/Home/HomeLogic.swift`:

```swift
import Foundation

/// Pure display rules for the Home tab. No UI, fully unit-tested.
enum HomeLogic {
    /// Whole replies the balance affords at the current tier price.
    static func approxReplies(balance: Int, costPerReply: Int) -> Int {
        guard costPerReply > 0, balance > 0 else { return 0 }
        return balance / costPerReply
    }

    /// Low state: can't afford a single reply (dev mode is never low).
    static func isLowBalance(balance: Int, costPerReply: Int, devMode: Bool) -> Bool {
        !devMode && balance < max(costPerReply, 1)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test command. Expected: `** TEST SUCCEEDED **` (5 new tests pass; existing
suites stay green).

- [ ] **Step 5: Commit**

```bash
git add Replr/Replr/Features/Captures/HistoryLogic.swift Replr/Replr/Features/Home/HomeLogic.swift Replr/ReplrTests/AppScreensLogicTests.swift
git commit -m "feat(ios): history/home display logic + tests (day groups, credits math)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Settings building blocks + About You editor

**Files:**
- Create: `Replr/Replr/Features/Settings/SettingsKit.swift`
- Create: `Replr/Replr/Features/Settings/AboutYouView.swift`

The root Settings screen and three sub-screens all need the same section/row/divider
furniture. Extract it once; `SettingsView`'s private helpers are replaced in Task 5.

- [ ] **Step 1: Create the shared kit**

Create `Replr/Replr/Features/Settings/SettingsKit.swift`:

```swift
import SwiftUI

/// Uppercase section title + content rows on a brand card.
/// Shared by SettingsView and its sub-screens.
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .brandCard()
        }
    }
}

/// One settings row: horizontal content, standard padding and tap target.
struct SettingsRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
    }
}

/// Hairline divider between rows on a card.
struct CardDivider: View {
    var body: some View {
        ReplrTheme.Color.glassBorder
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}

/// Accent value + chevrons menu trigger (used by pickers in Memory settings).
struct SettingsMenuPicker<Items: View>: View {
    let label: String
    @ViewBuilder var items: () -> Items

    var body: some View {
        Menu { items() } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 15))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(ReplrTheme.Color.accent)
        }
        .buttonStyle(.plain)
    }
}

/// Trailing "state" text on a row (e.g. "Natural", "All set ✓", "84").
struct RowValue: View {
    let text: String
    var color: Color = ReplrTheme.Color.textSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(color)
    }
}

/// Trailing chevron for navigation rows.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ReplrTheme.Color.textTertiary)
    }
}
```

- [ ] **Step 2: Create the About You editor**

Create `Replr/Replr/Features/Settings/AboutYouView.swift` (copy of today's inline
section from `SettingsView.aboutYouSection`, copy unchanged):

```swift
import SwiftUI

/// Free-text "About you" editor — opened from Settings and the Home tile.
struct AboutYouView: View {
    @State private var aboutUser = AppGroupService.shared.aboutUser
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: "About You") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(
                            "Age, gender, your vibe, what you're into…",
                            text: $aboutUser,
                            axis: .vertical
                        )
                        .font(.system(size: 15))
                        .lineLimit(3...6)
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                        .focused($focused)
                        .onChange(of: aboutUser) { newValue in
                            let capped = newValue.count > 300 ? String(newValue.prefix(300)) : newValue
                            if newValue.count > 300 { aboutUser = capped }
                            AppGroupService.shared.aboutUser = capped
                        }
                        Text("e.g. 27, guy, dry sense of humour, into climbing and techno")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textTertiary)
                            .padding(.top, 2)
                        Text("Stays on your device. Sent only to draft your replies.")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("About you")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.accent)
            }
        }
        .onAppear { aboutUser = AppGroupService.shared.aboutUser }
    }
}
```

- [ ] **Step 3: Build gate**

Run the build command. Expected: `** BUILD SUCCEEDED **` (new views compile unused;
the keyboard toolbar moving from the Settings row to this screen is exercised in
Task 5).

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/Features/Settings/SettingsKit.swift Replr/Replr/Features/Settings/AboutYouView.swift
git commit -m "feat(ios): settings building blocks + About You editor screen

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Memory settings (trust center) + memory sheet polish

**Files:**
- Create: `Replr/Replr/Features/Settings/MemorySettingsView.swift`
- Modify: `Replr/Replr/Features/Summaries/ContactMemoryDetailView.swift`

- [ ] **Step 1: Create MemorySettingsView**

Create `Replr/Replr/Features/Settings/MemorySettingsView.swift`. People-loading
logic is the old `MemoryViewModel` (deleted in Task 9) relocated:

```swift
import SwiftUI
import Combine

final class MemorySettingsViewModel: ObservableObject {
    @Published var people: [Contact] = []

    func load() {
        let sessions = AppGroupService.shared.loadCaptureSessions()
        let idsWithMemory = Set(sessions.compactMap { s -> UUID? in
            guard s.llmSummary != nil, let id = s.contactID else { return nil }
            return id
        })
        people = AppGroupService.shared.loadContacts().filter { idsWithMemory.contains($0.id) }
    }

    func rememberedCount(for contact: Contact) -> Int {
        AppGroupService.shared.sessions(forContactID: contact.id)
            .filter { $0.llmSummary != nil }
            .count
    }

    func clearMemory(for contact: Contact) {
        AppGroupService.shared.clearMemory(forContactID: contact.id)
        load()
    }

    func clearAll() {
        for contact in people { AppGroupService.shared.clearMemory(forContactID: contact.id) }
        people = []
    }
}

/// Settings → Memory: the trust center. Toggle + retrieval knobs + everyone
/// Replr remembers, with per-person detail and clear-all.
struct MemorySettingsView: View {
    @StateObject private var vm = MemorySettingsViewModel()
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var memoryWindowDays = AppGroupService.shared.memoryWindowDays
    @State private var memoryDepth = AppGroupService.shared.memoryDepth
    @State private var showClearAllConfirm = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: "Memory") {
                    SettingsRow {
                        Text("Use memory").font(.system(size: 17))
                        Spacer()
                        BrandToggle(isOn: $memoryEnabled)
                            .onChange(of: memoryEnabled) { AppGroupService.shared.memoryEnabled = $0 }
                    }
                }
                Text("Replr keeps a short summary of each chat, per person, on your phone — so the next reply knows the story so far.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 4)

                if memoryEnabled {
                    SettingsCard(title: "Retrieval") {
                        SettingsRow {
                            Text("Time window").font(.system(size: 17))
                            Spacer()
                            SettingsMenuPicker(label: memoryWindowDays == 0 ? "All time" : "\(memoryWindowDays) days") {
                                Button("7 days") { memoryWindowDays = 7; AppGroupService.shared.memoryWindowDays = 7 }
                                Button("30 days") { memoryWindowDays = 30; AppGroupService.shared.memoryWindowDays = 30 }
                                Button("90 days") { memoryWindowDays = 90; AppGroupService.shared.memoryWindowDays = 90 }
                                Button("All time") { memoryWindowDays = 0; AppGroupService.shared.memoryWindowDays = 0 }
                            }
                        }
                        CardDivider()
                        SettingsRow {
                            Text("Chats per person").font(.system(size: 17))
                            Spacer()
                            SettingsMenuPicker(label: "\(memoryDepth)") {
                                Button("5") { memoryDepth = 5; AppGroupService.shared.memoryDepth = 5 }
                                Button("10") { memoryDepth = 10; AppGroupService.shared.memoryDepth = 10 }
                                Button("20") { memoryDepth = 20; AppGroupService.shared.memoryDepth = 20 }
                            }
                        }
                    }
                }

                if !vm.people.isEmpty {
                    if !memoryEnabled {
                        Text("Memory is off — Replr isn't saving new conversations. What's below is still stored until you clear it.")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                            .padding(.horizontal, 4)
                    }

                    SettingsCard(title: "People") {
                        ForEach(Array(vm.people.enumerated()), id: \.element.id) { idx, contact in
                            if idx > 0 { CardDivider() }
                            NavigationLink(destination: ContactMemoryDetailView(
                                contact: contact,
                                onClearMemory: { vm.clearMemory(for: contact) }
                            )) {
                                SettingsRow {
                                    Circle()
                                        .fill(ReplrTheme.Color.accentSubtle)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text(String(contact.displayName.prefix(1)).uppercased())
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(ReplrTheme.Color.accent)
                                        )
                                    Text(contact.displayName)
                                        .font(.system(size: 17))
                                        .lineLimit(1)
                                    Spacer()
                                    let n = vm.rememberedCount(for: contact)
                                    RowValue(text: "\(n) chat\(n == 1 ? "" : "s")")
                                    RowChevron()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button { showClearAllConfirm = true } label: {
                        Text("Clear all memory")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(ReplrTheme.Color.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 110)
            }
            .animation(ReplrTheme.Motion.quick, value: memoryEnabled)
            .padding(20)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .tint(ReplrTheme.Color.accent)
        .confirmationDialog("Clear memory for everyone?",
                            isPresented: $showClearAllConfirm, titleVisibility: .visible) {
            Button("Clear all memory", role: .destructive) {
                withAnimation(ReplrTheme.Motion.quick) { vm.clearAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replr forgets every remembered conversation. Reply history is kept.")
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refresh() }
        }
    }

    private func refresh() {
        AppGroupService.shared.synchronize()
        vm.load()
        memoryEnabled = AppGroupService.shared.memoryEnabled
        memoryWindowDays = AppGroupService.shared.memoryWindowDays
        memoryDepth = AppGroupService.shared.memoryDepth
    }
}
```

- [ ] **Step 2: Polish ContactMemoryDetailView**

In `Replr/Replr/Features/Summaries/ContactMemoryDetailView.swift`, replace the `List`
content and drop the toolbar clear (explainer at top, destructive row at bottom):

```swift
    var body: some View {
        List {
            Text("Replr remembers a short summary of each chat so future replies stay in context. Summaries only, stored on your phone.")
                .font(.system(size: 13))
                .foregroundStyle(ReplrTheme.Color.textSecondary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 5) {
                    Text(formattedTimestamp(session.timestamp))
                        .font(.caption)
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                    if let summary = session.llmSummary {
                        Text(summary)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(ReplrTheme.Color.surface)
                .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
            }

            Button(role: .destructive) { showClearConfirm = true } label: {
                Text("Clear memory for \(contact.displayName)")
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .tint(ReplrTheme.Color.accent)
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.large)
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
```

(Everything else in the file — properties, `sessions`, `formattedTimestamp` — stays.)

- [ ] **Step 3: Build gate**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/Features/Settings/MemorySettingsView.swift Replr/Replr/Features/Summaries/ContactMemoryDetailView.swift
git commit -m "feat(ios): Memory settings trust center + memory sheet explainer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Screenshot settings sub-screen

**Files:**
- Create: `Replr/Replr/Features/Settings/ScreenshotSettingsView.swift`
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift` (move `ScreenshotCleaner` out)

- [ ] **Step 1: Move `ScreenshotCleaner` + build the screen**

Cut the entire `ScreenshotCleaner` enum (lines 4–28 of `SettingsView.swift`, including
its doc comment) and paste it unchanged at the top of the new file. `ReplrApp.swift`
also uses it; same target, so the move is transparent.

Create `Replr/Replr/Features/Settings/ScreenshotSettingsView.swift`:

```swift
import SwiftUI
import Photos

/// Deletes ONLY the screenshots Replr recorded (by localIdentifier). Never touches other photos.
enum ScreenshotCleaner {
    // … moved verbatim from SettingsView.swift …
}

/// Settings → Screenshots: cleanup toggles + the wordy explainers, off the root.
struct ScreenshotSettingsView: View {
    @State private var autoClear = AppGroupService.shared.autoClearScreenshots
    @State private var deleteAfterEach = AppGroupService.shared.deleteScreenshotAfterEach
    @State private var pendingShots = ScreenshotCleaner.pendingCount()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: "Cleanup") {
                    SettingsRow {
                        Text("Auto-clear captured screenshots").font(.system(size: 17))
                        Spacer()
                        BrandToggle(isOn: $autoClear)
                            .onChange(of: autoClear) { AppGroupService.shared.autoClearScreenshots = $0 }
                    }
                    if autoClear {
                        CardDivider()
                        SettingsRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete after each reply").font(.system(size: 17))
                                Text(deleteAfterEach ? "Each one, as soon as you reopen Replr" : "In batches, once a few pile up")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                            }
                            Spacer()
                            BrandToggle(isOn: $deleteAfterEach)
                                .onChange(of: deleteAfterEach) { AppGroupService.shared.deleteScreenshotAfterEach = $0 }
                        }
                    }
                    if pendingShots > 0 {
                        CardDivider()
                        Button {
                            ScreenshotCleaner.clean { _ in pendingShots = ScreenshotCleaner.pendingCount() }
                        } label: {
                            SettingsRow {
                                Text("Clear \(pendingShots) captured screenshot\(pendingShots == 1 ? "" : "s")")
                                    .font(.system(size: 17))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(ReplrTheme.Motion.quick, value: autoClear)
                .animation(ReplrTheme.Motion.quick, value: pendingShots)

                Text("Only deletes screenshots Replr captured for replies, never your other photos. Cleanup runs the next time you open Replr (iOS can't let the keyboard delete photos on its own), and iOS asks you to confirm.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 4)

                if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Faster capture on iOS 26")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.textPrimary)
                        Text("Screenshots open a full editor instead of saving on their own. For one-tap capture, open the Settings app → Screen Capture and turn off Full-Screen Previews. Optional: capture still works, you'll just tap Save first.")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                }
                Spacer(minLength: 110)
            }
            .padding(20)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { pendingShots = ScreenshotCleaner.pendingCount() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { pendingShots = ScreenshotCleaner.pendingCount() }
        }
    }
}
```

(The `// … moved verbatim …` marker means: paste the exact 25 lines from
`SettingsView.swift` — `pendingCount()` and `clean(completion:)` — without edits.)

- [ ] **Step 2: Build gate**

Run the build command. Expected: `** BUILD SUCCEEDED **`. If `ScreenshotCleaner` is
redeclared, the cut from `SettingsView.swift` was missed — remove it there.

- [ ] **Step 3: Commit**

```bash
git add Replr/Replr/Features/Settings/ScreenshotSettingsView.swift Replr/Replr/Features/Settings/SettingsView.swift
git commit -m "feat(ios): Screenshots settings sub-screen; ScreenshotCleaner moves with it

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Settings root regroup

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

`SetupStatusView` (in the same file) is untouched. The `SettingsView` struct is
rewritten; `performDeleteAccount`, the delete-account dialogs, `appearanceOption`,
and `modelOption` survive as-is.

- [ ] **Step 1: Rewrite SettingsView**

Replace the `SettingsView` struct with:

```swift
struct SettingsView: View {
    @AppStorage(Constants.colorSchemeAppearanceKey) private var colorSchemeAppearance = "system"
    @State private var persistReplies = AppGroupService.shared.persistReplies
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var autoClear = AppGroupService.shared.autoClearScreenshots
    @State private var activeToneName = AppGroupService.shared.readSelectedTone().name
    @State private var aboutUser = AppGroupService.shared.aboutUser
    @State private var selectedModel = AppGroupService.shared.userModel
    @State private var showModelPicker = false
    @State private var showTutorial = false
    @State private var showBackTapSetup = false
    @State private var fullAccess = AppGroupService.shared.fullAccessGranted
    @State private var photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showSignOutConfirm = false
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var credits = CreditsManager.shared
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    #endif

    private var photosOK: Bool { photosStatus == .authorized || photosStatus == .limited }
    private var setupMissing: Int { (fullAccess ? 0 : 1) + (photosOK ? 0 : 1) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    personalizeSection
                    keyboardSection
                    privacySection
                    accountSection
                    footerSection
                    Spacer(minLength: 110) // clearance for floating tab pill
                }
                .padding(20)
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            UsageTutorialView(onDone: { showTutorial = false })
        }
        .sheet(isPresented: $showBackTapSetup) {
            BackTapSetupFullView(isPresented: $showBackTapSetup)
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { phase in if phase == .active { refresh() } }
    }

    private func refresh() {
        AppGroupService.shared.synchronize()
        activeToneName = AppGroupService.shared.readSelectedTone().name
        aboutUser = AppGroupService.shared.aboutUser
        memoryEnabled = AppGroupService.shared.memoryEnabled
        autoClear = AppGroupService.shared.autoClearScreenshots
        selectedModel = AppGroupService.shared.userModel
        fullAccess = AppGroupService.shared.fullAccessGranted
        photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        CreditsManager.shared.refreshBalance()
    }

    // MARK: - Personalize

    private var personalizeSection: some View {
        SettingsCard(title: "Personalize") {
            NavigationLink(destination: AboutYouView().onDisappear {
                aboutUser = AppGroupService.shared.aboutUser
            }) {
                SettingsRow {
                    Text("About you").font(.system(size: 17))
                    Spacer()
                    RowValue(text: aboutUser.isEmpty ? "Add" : "Added ✓",
                             color: aboutUser.isEmpty ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            NavigationLink(destination: TonesView().onDisappear {
                activeToneName = AppGroupService.shared.readSelectedTone().name
            }) {
                SettingsRow {
                    Text("Tones").font(.system(size: 17))
                    Spacer()
                    RowValue(text: activeToneName)
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    modelOption("balanced", label: "Balanced", sublabel: "Recommended")
                    ReplrTheme.Color.glassBorder.frame(width: 1, height: 38)
                    modelOption("max", label: "Max", sublabel: "Best quality")
                }
                .padding(6)
                Text("Balanced 4 · Max 6 credits per reply.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Keyboard

    private var keyboardSection: some View {
        SettingsCard(title: "Keyboard") {
            NavigationLink(destination: SetupStatusView()) {
                SettingsRow {
                    Text("Set up Replr").font(.system(size: 17))
                    Spacer()
                    RowValue(text: setupMissing == 0 ? "All set ✓" : "\(setupMissing) step\(setupMissing == 1 ? "" : "s") left",
                             color: setupMissing == 0 ? ReplrTheme.Color.success : ReplrTheme.Color.accent)
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            Button { showBackTapSetup = true } label: {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Back Tap capture").font(.system(size: 17))
                        Text("Optional: screenshot anywhere, no keyboard needed")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                    Spacer()
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            Button { showTutorial = true } label: {
                SettingsRow {
                    Text("How to use Replr").font(.system(size: 17))
                    Spacer()
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            SettingsRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep replies in keyboard").font(.system(size: 17))
                    Text("They stay until you generate new ones")
                        .font(.system(size: 12))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
                Spacer()
                BrandToggle(isOn: $persistReplies)
                    .onChange(of: persistReplies) { AppGroupService.shared.persistReplies = $0 }
            }
        }
    }

    // MARK: - Privacy & data

    private var privacySection: some View {
        SettingsCard(title: "Privacy & Data") {
            NavigationLink(destination: MemorySettingsView().onDisappear {
                memoryEnabled = AppGroupService.shared.memoryEnabled
            }) {
                SettingsRow {
                    Text("Memory").font(.system(size: 17))
                    Spacer()
                    RowValue(text: memoryEnabled ? "On" : "Off")
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            NavigationLink(destination: ScreenshotSettingsView().onDisappear {
                autoClear = AppGroupService.shared.autoClearScreenshots
            }) {
                SettingsRow {
                    Text("Screenshots").font(.system(size: 17))
                    Spacer()
                    RowValue(text: autoClear ? "Auto-clear" : "Manual")
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            NavigationLink(destination: PrivacyView()) {
                SettingsRow {
                    Text("Privacy").font(.system(size: 17))
                    Spacer()
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        SettingsCard(title: "Account") {
            NavigationLink(destination: CreditPacksView()) {
                SettingsRow {
                    Text("Credits").font(.system(size: 17))
                    Spacer()
                    RowValue(text: credits.balanceDisplay)
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            CardDivider()
            SettingsRow {
                Text(auth.userEmail ?? "Signed in with Apple")
                    .font(.system(size: 15))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Sign out") { showSignOutConfirm = true }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ReplrTheme.Color.danger)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
            }
            if auth.isSignedIn {
                CardDivider()
                Button { showDeleteAccountConfirm = true } label: {
                    SettingsRow {
                        Text("Delete account")
                            .font(.system(size: 17))
                            .foregroundStyle(ReplrTheme.Color.danger)
                        Spacer()
                        if isDeletingAccount { ProgressView() }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
            }
        }
        .confirmationDialog("Sign out of Replr?",
                            isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete your account?",
                            isPresented: $showDeleteAccountConfirm,
                            titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { performDeleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and any remaining credits. It can't be undone.")
        }
        .alert("Couldn't delete account",
               isPresented: Binding(
                   get: { deleteAccountError != nil },
                   set: { if !$0 { deleteAccountError = nil } }
               )) {
            Button("OK", role: .cancel) { deleteAccountError = nil }
        } message: {
            Text(deleteAccountError ?? "")
        }
    }

    // MARK: - Footer (cold storage)

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsCard(title: "Appearance") {
                    HStack(spacing: 0) {
                        appearanceOption("system", icon: "iphone",  label: "System")
                        ReplrTheme.Color.glassBorder.frame(width: 1, height: 58)
                        appearanceOption("light",  icon: "sun.max", label: "Light")
                        ReplrTheme.Color.glassBorder.frame(width: 1, height: 58)
                        appearanceOption("dark",   icon: "moon",    label: "Dark")
                    }
                    .padding(6)
                }
                Text("Overrides the system setting for Replr only.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 4)
            }

            SettingsCard(title: "About") {
                NavigationLink(destination: ModelPickerView(), isActive: $showModelPicker) {
                    EmptyView()
                }
                SettingsRow {
                    Text("Version").font(.system(size: 17))
                    Spacer()
                    RowValue(text: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
                .onLongPressGesture(minimumDuration: 1.5) {
                    showModelPicker = true
                }
                #if DEBUG
                CardDivider()
                Button {
                    AppGroupService.shared.creditBalance = max(AppGroupService.shared.creditBalance, 40)
                    CreditsManager.shared.refreshBalance()
                    onboardingComplete = false
                } label: {
                    SettingsRow {
                        Text("Replay onboarding (+credits)").font(.system(size: 17))
                        Spacer()
                        Text("DEBUG")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                #endif
            }
        }
    }

    private func performDeleteAccount() {
        // … unchanged from today …
    }

    // appearanceOption(_:icon:label:) and modelOption(_:label:sublabel:) stay unchanged.
}
```

Deletions from the old struct: `identityCard`, `aboutYouSection`, `memorySection`,
`screenshotSection`, `aboutSection` (folded into `footerSection`), the old
`accountSection`/`keyboardSection`/`appearanceSection` bodies, the private
`settingsSection`/`settingsRow`/`cardDivider`/`menuPicker` helpers (SettingsKit
replaces them), and now-unused state: `memoryWindowDays`, `memoryDepth`,
`deleteAfterEach`, `pendingShots`, `preferredCapture`, `aboutFocused`.
`performDeleteAccount()` is kept verbatim. `import Photos` stays (setup status).

- [ ] **Step 2: Build gate**

Run the build command. Expected: `** BUILD SUCCEEDED **`. Common failures: a deleted
helper still referenced (search `settingsSection(` → must be zero hits), or
`menuPicker(` leftovers.

- [ ] **Step 3: Commit**

```bash
git add Replr/Replr/Features/Settings/SettingsView.swift
git commit -m "refactor(ios): Settings root regrouped — stateful rows, sub-screens, account reorder

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: History part 1 — rename, day groups, toolbar, empty state

**Files:**
- Rename: `Replr/Replr/Features/Captures/CaptureLogView.swift` → `Replr/Replr/Features/Captures/HistoryView.swift`
- Modify: `Replr/Replr/App/ReplrApp.swift:155` (one identifier)

- [ ] **Step 1: Rename file and type**

```bash
git mv Replr/Replr/Features/Captures/CaptureLogView.swift Replr/Replr/Features/Captures/HistoryView.swift
```

In the renamed file: `struct RepliesView: View` → `struct HistoryView: View`.
In `ReplrApp.swift` line 155: `RepliesView()` → `HistoryView()`.
(`RepliesViewModel` keeps its name — it's the same model.)

- [ ] **Step 2: Day-grouped list, menu toolbar, simpler empty state**

In `HistoryView.swift`:

a) Navigation title: `.navigationTitle("Replies")` → `.navigationTitle("History")`.

b) Replace the session-cards `ScrollView` block (the `ScrollView { LazyVStack … }`)
with day sections:

```swift
                    // Session cards, grouped by day
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(HistoryLogic.dayGroups(vm.filteredSessions, date: \.timestamp),
                                    id: \.day) { group in
                                Text(group.label.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1.0)
                                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 6)
                                ForEach(group.items) { session in
                                    NavigationLink(destination: CaptureDetailView(session: session)) {
                                        CaptureRowView(session: session)
                                    }
                                    .buttonStyle(.plain)
                                    .brandCard()
                                    .contextMenu {
                                        Button(role: .destructive) { vm.deleteSession(session) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
```

c) Replace the toolbar "Clear all" pill with a menu:

```swift
            .toolbar {
                if !vm.sessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) { showClearConfirm = true } label: {
                                Label("Clear all history", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(ReplrTheme.Color.accent)
                        }
                    }
                }
            }
```

d) Replace `emptyState` (and delete the now-unused `emptyHowToRow`) — Home teaches
the steps now:

```swift
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(ReplrTheme.Color.accentSubtle)
                    .frame(width: 72, height: 72)
                Image(systemName: "clock")
                    .font(.system(size: 30))
                    .foregroundStyle(ReplrTheme.Color.accent)
            }
            Text("Replies you generate show up here")
                .font(ReplrTheme.Font.headline)
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            TertiaryButton(label: "See how it works") { showTutorial = true }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
```

Add state + presentation alongside the existing sheet modifiers:

```swift
    @State private var showTutorial = false
```
```swift
            .fullScreenCover(isPresented: $showTutorial) {
                UsageTutorialView(onDone: { showTutorial = false })
            }
```

(`TertiaryButton(label:action:)` is the verified signature — `Shared/ReplrComponents.swift:119`.)

e) Delete the Back Tap banner: remove the `if backTapSkipped { … }` block at the top
of `body`, plus the `backTapSkipped` / `showSetupSheet` state, the
`.sheet(isPresented: $showSetupSheet)` modifier, and the `backTapSkipped`
re-reads in `onAppear`. (Home takes this job in Task 8.)

- [ ] **Step 3: Build gate**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -A Replr/Replr/Features/Captures Replr/Replr/App/ReplrApp.swift
git commit -m "feat(ios): History tab — rename, day-grouped sections, overflow menu, lean empty state

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: History part 2 — person header, card cleanup, dev-gated detail chips

**Files:**
- Modify: `Replr/Replr/Features/Captures/HistoryView.swift`

- [x] **Step 1: Person header replaces the memory banner**

In `HistoryView.swift`, replace the whole "Memory shortcut banner" block
(`if let id = vm.selectedContactID, memoryEnabled, … ReplrTheme.Color.glassBorder.frame(height: 0.5)`)
with:

```swift
                    // Person header — the contact's identity + memory entry point
                    if let id = vm.selectedContactID,
                       let contact = vm.allContacts.first(where: { $0.id == id }) {
                        personHeader(contact)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    }
```

Add below the `filterChip` helper:

```swift
    private func rememberedCount(id: UUID) -> Int {
        AppGroupService.shared.sessions(forContactID: id).filter { $0.llmSummary != nil }.count
    }

    @ViewBuilder
    private func personHeader(_ contact: Contact) -> some View {
        let replies = vm.filteredSessions.count
        let remembered = rememberedCount(id: contact.id)
        HStack(spacing: 12) {
            Circle()
                .fill(ReplrTheme.Color.accentSubtle)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(contact.displayName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                Text(memoryEnabled
                     ? HistoryLogic.personSubtitle(replies: replies, remembered: remembered)
                     : "Memory is off — turn on in Settings")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            Spacer()
            if !memoryEnabled {
                Button { showMemorySettings = true } label: {
                    memoryPill(label: "Memory settings")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if remembered > 0 {
                Button { memoryContact = contact } label: {
                    memoryPill(label: "Memory")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(ReplrTheme.Color.accentSubtle.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(ReplrTheme.Color.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func memoryPill(label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ReplrTheme.Color.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().strokeBorder(ReplrTheme.Color.accent.opacity(0.5), lineWidth: 1))
    }
```

Add state and the sheet (next to the existing `memoryContact` sheet):

```swift
    @State private var showMemorySettings = false
```
```swift
        .sheet(isPresented: $showMemorySettings, onDismiss: {
            memoryEnabled = AppGroupService.shared.memoryEnabled
        }) {
            NavigationStack { MemorySettingsView() }
        }
```

- [x] **Step 2: Card cleanup**

In `CaptureRowView` (same file):

a) Add a parameter: `var showsContactName: Bool = true`. The name row becomes:

```swift
                HStack(alignment: .center, spacing: 6) {
                    if let name = session.contactName, showsContactName {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(formattedTimestamp(session.timestamp))
                        .font(.system(size: 11))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
```

(This removes the sparkles glyph and the `hasMemory` computed property — delete it.)

b) Label the used reply (replace the bare-checkmark `if let selected …` block):

```swift
                    if let selected = session.selectedReply {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ReplrTheme.Color.accent)
                            Text("Used: \u{201C}\(selected)\u{201D}")
                                .font(.caption)
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
```

c) Lighter empty-thumbnail placeholder — in the `else` branch swap
`.fill(ReplrTheme.Color.surfaceRaised)` for `.fill(ReplrTheme.Color.accentSubtle.opacity(0.5))`.

d) At the call site in `HistoryView`, pass the flag:

```swift
                                        CaptureRowView(session: session,
                                                       showsContactName: vm.selectedContactID == nil)
```

- [x] **Step 3: Dev-gate the internals chips in CaptureDetailView**

Tone chip is always user-facing; only model/cost/tokens are dev-only internals.
Restructure so the outer `HStack` is unconditional, with only the cpu/cost chips inside a
`devMode` check, and the tokens row separately gated:

```swift
                // Capture intelligence — tone is user-facing; model/cost/tokens are internals.
                HStack(spacing: 10) {
                    if let tone = session.toneName {
                        infoChip(icon: "waveform", label: tone)
                    }
                    if AppGroupService.shared.devMode {
                        if let model = session.modelUsed {
                            infoChip(icon: "cpu", label: model)
                        }
                        if let cost = session.costUsd {
                            infoChip(icon: "dollarsign.circle", label: String(format: "$%.4f", cost))
                        }
                    }
                }
                if AppGroupService.shared.devMode,
                   let input = session.inputTokens, let output = session.outputTokens {
                    HStack(spacing: 10) {
                        infoChip(icon: "arrow.down.circle", label: "\(input) in")
                        infoChip(icon: "arrow.up.circle", label: "\(output) out")
                    }
                }
```

- [x] **Step 3b: Code-review fixes (not in original plan)**

Three review polish items applied after initial implementation:

  a) `memoryEnabled` refresh: the `.sheet(isPresented: $showMemorySettings)` modifier gained
  `onDismiss: { memoryEnabled = AppGroupService.shared.memoryEnabled }` so the person
  header subtitle and pill update immediately after the Memory settings sheet closes.

  b) Tone chip un-gated: the original dev-mode wrapper enclosed tone + model + cost + tokens.
  Restructured to always show the tone chip (it is user-facing), while cpu/cost chips and the
  tokens row remain dev-only (see Step 3 above).

  c) HIG tap targets on memory pills: both pill `Button` labels gained
  `.frame(minHeight: 44).contentShape(Rectangle())` so the tap area meets the 44 pt HIG minimum.

- [x] **Step 4: Review follow-ups folded in (not in original plan)**

Two polish items from the Task 6 review were merged into this task:

  a) Alert copy: `"Clear all captures?"` → `"Clear all history?"` and message
  `"This deletes all captured replies and conversation history. Memory paragraphs are kept."` →
  `"This deletes your reply history. Memory is kept."`

  b) Empty state button: replaced `TertiaryButton(label: "See how it works")` with an
  accent `.foregroundStyle` text button (`font .semibold 15, minHeight 44, .buttonStyle(.plain)`)
  so it reads as tappable without an implicit button style.

- [x] **Step 4 (original): `formattedTimestamp` simplification** (not listed in original plan)

  `CaptureRowView.formattedTimestamp` was simplified to `date.formatted(.dateTime.hour().minute())`
  — day context is now carried by the section header (day-group label), so the row only needs
  the time. The old multi-branch `Today · HH:mm` / `Yesterday · HH:mm` / full-date format is gone.

- [x] **Step 5: Build gate**

Run the build command. Expected: `** BUILD SUCCEEDED **`. ✓ Confirmed.

- [x] **Step 6: Commit**

```bash
git add Replr/Replr/Features/Captures/HistoryView.swift docs/superpowers/plans/2026-06-11-app-screens-ux.md
git commit -m "feat(ios): person header with memory entry; clearer cards; dev-only metric chips

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Home tab

**Files:**
- Create: `Replr/Replr/Features/Home/HomeView.swift`

Compiles unused until Task 9 wires it in. `TabSelection` still has the old cases, so
the tab binding is introduced in Task 9 — here `HomeView` takes an `onSeeAll` closure
instead, keeping this task independent of the enum change.

- [x] **Step 1: Create HomeView + view model**

Create `Replr/Replr/Features/Home/HomeView.swift`:

```swift
import SwiftUI
import Photos
import Combine

final class HomeViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []
    @Published var fullAccess = false
    @Published var photosOK = false
    @Published var backTapSkipped = false
    @Published var activeToneName = ""
    @Published var aboutAdded = false

    var setupComplete: Bool { fullAccess && photosOK }
    var recent: [CaptureSession] { Array(sessions.prefix(3)) }

    func refresh() {
        AppGroupService.shared.synchronize()
        sessions = AppGroupService.shared.loadCaptureSessions().reversed()
        fullAccess = AppGroupService.shared.fullAccessGranted
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosOK = status == .authorized || status == .limited
        backTapSkipped = AppGroupService.shared.backTapSkipped
        activeToneName = AppGroupService.shared.readSelectedTone().name
        aboutAdded = !AppGroupService.shared.aboutUser.isEmpty
        CreditsManager.shared.refreshBalance()
    }
}

/// Mission control: setup state, credits, recent replies, personalization.
struct HomeView: View {
    var onSeeAll: () -> Void = {}
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var credits = CreditsManager.shared
    @State private var showSetup = false
    @State private var showBackTap = false
    @State private var showTutorial = false
    @State private var showTones = false
    @Environment(\.scenePhase) private var scenePhase

    private var costPerReply: Int { AppGroupService.shared.creditsRequired }
    private var devMode: Bool { AppGroupService.shared.devMode }
    private var lowBalance: Bool {
        HomeLogic.isLowBalance(balance: AppGroupService.shared.effectiveCreditBalance,
                               costPerReply: costPerReply, devMode: devMode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !vm.setupComplete { setupCard }
                    if vm.setupComplete && vm.backTapSkipped { backTapRow }
                    creditsCard
                    if vm.sessions.isEmpty { howItWorksCard } else { recentSection }
                    personalizeTiles
                    Spacer(minLength: 110) // clearance for floating tab pill
                }
                .padding(20)
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .navigationTitle("Replr")
            .navigationBarTitleDisplayMode(.inline)
            .tint(ReplrTheme.Color.accent)
        }
        .onAppear { vm.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { vm.refresh() }
        }
        .sheet(isPresented: $showSetup) {
            OnboardingView(
                onComplete: { showSetup = false; vm.refresh() },
                onSignIn: { showSetup = false },
                startAtSetup: true
            )
        }
        .sheet(isPresented: $showBackTap) {
            BackTapSetupFullView(isPresented: $showBackTap)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            UsageTutorialView(onDone: { showTutorial = false })
        }
        .sheet(isPresented: $showTones) {
            TonesView()
        }
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finish setting up")
                .font(ReplrTheme.Font.headline)
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            setupRow("Keyboard & Full Access", on: vm.fullAccess)
            setupRow("Photos access", on: vm.photosOK)
            PrimaryButton(label: "Finish setup") { showSetup = true }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(ReplrTheme.Color.accent.opacity(0.45), lineWidth: 1.5)
        )
    }

    private func setupRow(_ title: String, on: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(on ? ReplrTheme.Color.success : ReplrTheme.Color.textTertiary)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Spacer()
        }
    }

    private var backTapRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .font(.system(size: 14))
                .foregroundStyle(ReplrTheme.Color.accent)
            Text("Back Tap: screenshot anywhere, no keyboard needed")
                .font(.system(size: 13))
                .foregroundStyle(ReplrTheme.Color.textSecondary)
            Spacer()
            Button("Set up") { showBackTap = true }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.accent)
                .buttonStyle(.plain)
            Button {
                AppGroupService.shared.backTapSkipped = false
                vm.backTapSkipped = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(ReplrTheme.Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Credits

    private var creditsCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(devMode ? "∞" : credits.balanceDisplay)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                    Text("credits")
                        .font(.system(size: 13))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
                Text(creditsSubline)
                    .font(.system(size: 12))
                    .foregroundStyle(lowBalance ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary)
            }
            Spacer()
            NavigationLink(destination: CreditPacksView()) {
                Text(lowBalance ? "Top up" : "Get more")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(lowBalance ? ReplrTheme.Color.onAccent : ReplrTheme.Color.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(lowBalance ? ReplrTheme.Color.accent : ReplrTheme.Color.accentSubtle)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .brandCard()
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(lowBalance ? ReplrTheme.Color.accent.opacity(0.45) : .clear, lineWidth: 1.5)
        )
    }

    private var creditsSubline: String {
        if devMode { return "Dev mode — replies are free" }
        let n = HomeLogic.approxReplies(balance: AppGroupService.shared.effectiveCreditBalance,
                                        costPerReply: costPerReply)
        if n == 0 { return "Not enough for a reply" }
        return "≈ \(n) repl\(n == 1 ? "y" : "ies")"
    }

    // MARK: - How it works (until first capture)

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Replr works")
                .font(ReplrTheme.Font.headline)
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            stepRow("1", "Open a chat and switch to the Replr keyboard (🌐).")
            stepRow("2", "Tap \u{201C}Start\u{201D}, then screenshot the chat.")
            stepRow("3", "Tap a reply to send it.")
            Button { showTutorial = true } label: {
                Text("Watch how →")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func stepRow(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(ReplrTheme.Color.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ReplrTheme.Color.accent))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                Spacer()
                Button { onSeeAll() } label: {
                    Text("See all →")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ReplrTheme.Color.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            ForEach(vm.recent) { session in
                NavigationLink(destination: CaptureDetailView(session: session)) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(session.contactName ?? recentTime(session.timestamp))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                                    .lineLimit(1)
                                if session.contactName != nil {
                                    Text(recentTime(session.timestamp))
                                        .font(.system(size: 11))
                                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                                }
                            }
                            if let summary = session.llmSummary {
                                Text(summary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.textTertiary)
                    }
                    .padding(12)
                }
                .buttonStyle(.plain)
                .brandCard()
            }
        }
    }

    private func recentTime(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return date.formatted(.dateTime.hour().minute()) }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Personalize

    private var personalizeTiles: some View {
        HStack(spacing: 10) {
            Button { showTones = true } label: {
                tile(caption: "Tone", value: vm.activeToneName)
            }
            .buttonStyle(.plain)
            NavigationLink(destination: AboutYouView().onDisappear { vm.refresh() }) {
                tile(caption: "About you", value: vm.aboutAdded ? "Added ✓" : "Add")
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(caption: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(ReplrTheme.Color.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
```

- [x] **Step 2: Build gate**

Run the build command. Expected: `** BUILD SUCCEEDED **`. ✅ 2026-06-11

- [x] **Step 3: Commit**

```bash
git add Replr/Replr/Features/Home/HomeView.swift
git commit -m "feat(ios): Home tab — setup card, credits with low state, recent, personalize tiles

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Review carry-forward folded in (applied in separate review-fix commit):

- `BackTapOnboardingStep.swift` was already orphaned by commit 299e3a1 (no call sites). The file is now deleted via `git rm`. The `backTapSkipped = true` writer was moved to `OnboardingView`'s single completion path — the `SampleDemoStep(onFinish:)` closure in case 6 — so Home's suggestion row works for all fresh installs.
- Animated row dismissal: the ✕ button's `vm.backTapSkipped = false` is wrapped in `withAnimation(ReplrTheme.Motion.quick)` to prevent layout jumps.
- Credits card single source of truth: `lowBalance` and `creditsSubline` now read `credits.balance` (the `@ObservedObject`-published value) instead of directly calling `AppGroupService.shared.effectiveCreditBalance`, eliminating the one-frame disagreement between the big number and the sub-line/border.
- Tones sheet refresh: `.sheet(isPresented: $showTones)` gains `onDismiss: { vm.refresh() }` so the Tone tile value updates after the sheet closes.

---

### Task 9: Tab wiring — Home in, Memory out ✅ 2026-06-11

**Files:**
- Modify: `Replr/Replr/App/CustomTabBar.swift`
- Modify: `Replr/Replr/App/ReplrApp.swift` (ContentView)
- Modify: `Replr/Replr/Features/Home/HomeView.swift`
- Modify: `Replr/Replr/Features/Captures/HistoryView.swift`
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`
- Delete: `Replr/Replr/Features/Memory/MemoryView.swift`

**Carry-forward fixed here:** the opacity-ZStack shell keeps tab roots alive, so
`onAppear` fires only once per launch. Each root now refreshes when its own tab becomes
selected (binding/value param + `onChange`), in addition to `onAppear`/`scenePhase`.

- [x] **Step 1: Update the enum and tab bar**

In `CustomTabBar.swift`:

```swift
enum TabSelection: Hashable { case home, history, settings }
```

and the three buttons:

```swift
            tabButton(.home,     icon: "house",     activeIcon: "house.fill",     label: "Home")
            tabButton(.history,  icon: "clock",     activeIcon: "clock.fill",     label: "History")
            tabButton(.settings, icon: "gearshape", activeIcon: "gearshape.fill", label: "Settings")
```

- [x] **Step 2: Rewire ContentView**

In `ReplrApp.swift`, `ContentView` becomes (`.task` blocks byte-identical to prior):

```swift
struct ContentView: View {
    @State private var selectedTab: TabSelection = .home

    var body: some View {
        ZStack {
            HomeView(selectedTab: $selectedTab)
                .opacity(selectedTab == .home ? 1 : 0)
                .allowsHitTesting(selectedTab == .home)
            HistoryView(activeTab: selectedTab)
                .opacity(selectedTab == .history ? 1 : 0)
                .allowsHitTesting(selectedTab == .history)
            SettingsView(activeTab: selectedTab)
                .opacity(selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(selectedTab == .settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $selectedTab)
                .ignoresSafeArea(.keyboard) // pin tab bar to screen bottom — keyboard must not push it up
        }
        .task {
            // Variant first so the product list loads in the served order.
            await PaywallService.refresh()
            await CreditsManager.shared.load()
        }
        .task {
            await RemoteConfig.refresh()
        }
    }
}
```

- [x] **Step 3: HomeView — binding replaces closure + own-tab refresh**

  a) `var onSeeAll: () -> Void = {}` → `@Binding var selectedTab: TabSelection`
  b) "See all →" button action: `onSeeAll()` → `selectedTab = .history`
  c) After `.onChange(of: scenePhase)` modifier, add:
  ```swift
          .onChange(of: selectedTab) { tab in
              if tab == .home { vm.refresh() }
          }
  ```

- [x] **Step 4: HistoryView — own-tab refresh**

  a) First stored property (above `@StateObject`): `let activeTab: TabSelection`
  b) After `.onChange(of: scenePhase)` modifier, add:
  ```swift
          .onChange(of: activeTab) { tab in
              guard tab == .history else { return }
              AppGroupService.shared.synchronize()
              vm.load()
              memoryEnabled = AppGroupService.shared.memoryEnabled
          }
  ```

- [x] **Step 5: SettingsView — own-tab refresh**

  a) First stored property (above `@AppStorage`): `let activeTab: TabSelection`
  b) After `.onChange(of: scenePhase)` modifier, add:
  ```swift
          .onChange(of: activeTab) { tab in if tab == .settings { refresh() } }
  ```

- [x] **Step 6: Delete the Memory tab**

```bash
git rm Replr/Replr/Features/Memory/MemoryView.swift
```

Then verify nothing else references it:

```bash
grep -rn "MemoryView\b\|MemoryViewModel\b" --include="*.swift" Replr/Replr Replr/ReplrKeyboard Shared | grep -v "MemorySettings"
```
Expected: zero lines. ✓ Confirmed.

- [x] **Step 7: Build gate**

Run the build command. Expected: `** BUILD SUCCEEDED **`. ✓ Confirmed.

- [x] **Step 8: Sanity greps**

```bash
grep -rn "case .replies\|case .memory\|\.replies\b\|\.memory\b\|onSeeAll" --include="*.swift" Replr/Replr Shared
```
Expected: zero hits for old TabSelection cases and closure. ✓ Confirmed (`.replies` hits
in `ReplyResult` struct and `ReplyService` are unrelated `.replies` property names — not
the `TabSelection` enum case).

- [x] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(ios): Home/History/Settings tabs — Home default, Memory tab retired

Each tab root also refreshes on its own tab activation: the opacity
ZStack shell keeps roots alive, so onAppear fires once per launch.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Full verification + docs

**Files:**
- Modify: `docs/HANDOFF.md` (pending-tasks section)

- [ ] **Step 1: Run the full test suite**

Run the test command from the header.
Expected: `** TEST SUCCEEDED **` — all suites including `AppScreensLogicTests`.

- [ ] **Step 2: Clean-state sanity greps**

```bash
grep -rn "RepliesView\|TabSelection.replies\|case .replies\|case .memory" --include="*.swift" Replr Shared
```
Expected: zero hits.

```bash
grep -rn "settingsSection(\|menuPicker(\|identityCard" Replr/Replr/Features/Settings/SettingsView.swift
```
Expected: zero hits.

- [ ] **Step 3: Update HANDOFF.md**

In `docs/HANDOFF.md` §4 "Pending / next tasks", replace item `0.` (Settings UX pass)
with:

```markdown
0. ~~Settings UX pass~~ — DONE 2026-06-11 on `app-screens`: app restructured to
   Home / History / Settings per
   `docs/superpowers/specs/2026-06-11-app-screens-ux-design.md` (Home = setup +
   credits + recent; Memory tab folded into History's person header +
   Settings → Memory; Settings root regrouped with sub-screens). Awaiting
   owner device pass (dark + light) before merge.
```

- [ ] **Step 4: Commit**

```bash
git add docs/HANDOFF.md
git commit -m "docs: HANDOFF — app-screens redesign built, pending device pass

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Final review follow-ups: filter-chip sparkles actually dropped (was missed in Task 7), RepliesViewModel→HistoryViewModel rename completed, CLAUDE.md test-scheme line corrected.

- [ ] **Step 5: Manual device pass (owner)**

Hand back for the on-device review against the UX-taste checklist — no clipping,
contained controls, conventional placements, breathing room, no layout jumps, copy
matches the OS — in dark **and** light. Items to specifically eyeball: Home setup
card → credits card spacing, History person header with/without memory, Settings
root scroll length, low-balance credits state (set balance < 4 via debug), tab pill
clearance at the bottom of every scroll.

---

## Self-review notes (already applied)

- Spec coverage: Home blocks 1–6 → Task 8; History rename/groups/menu/empty → Task 6;
  person header/cards/dev-gating → Task 7; memory sheet polish → Task 3; Settings
  root/groups/account order/cold storage → Task 5; sub-screens → Tasks 2–4; tab
  wiring/deletion/default → Task 9; tests → Tasks 1 & 10; HANDOFF → Task 10.
- Deviation from spec (1): swipe-to-delete on History rows is dropped — rows are
  custom cards in a `ScrollView`/`LazyVStack`, and `swipeActions` requires `List`;
  converting risks the card styling and scroll behavior for marginal gain. Long-press
  delete (existing) stays. The spec file is amended accordingly.
- Deviation from spec (2): `MemorySettingsView` People rows clear via the detail
  screen (existing flow) rather than swipe, for the same `List` reason.
- Type consistency: `HistoryLogic.dayGroups(_:date:now:calendar:locale:)`,
  `HomeLogic.approxReplies(balance:costPerReply:)`, `HomeLogic.isLowBalance(...)`,
  `SettingsCard(title:content:)`, `SettingsRow(content:)`, `CardDivider()`,
  `SettingsMenuPicker(label:items:)`, `RowValue(text:color:)`, `RowChevron()`,
  `CaptureRowView(session:showsContactName:)`, `HomeView(onSeeAll:)` — used
  identically across tasks.
