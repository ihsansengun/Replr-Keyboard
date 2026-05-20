# Companion App UX Redesign

## Goal

Collapse the companion app from four tabs to two. Settings becomes the primary home. History (formerly Captures) is the secondary tab. Memory and Tones are no longer standalone tabs — they fold into Settings and History respectively.

## Architecture

**TabView with two tabs:**
- Tab 1: Settings (`gearshape` icon) — opens by default
- Tab 2: History (`clock` icon) — renamed from Captures

**Memory** is an optional, user-controlled feature. When enabled, it builds per-contact AI summaries silently. The Memory detail view (list of summaries per contact) is accessible by tapping a contact chip in History — it is not a top-level destination.

**Tones** are managed from a navigation row inside Settings, not a standalone tab.

---

## Tab 1: Settings

**File:** `Replr/Features/Settings/SettingsView.swift`

Replaces the current 4-section Form. Structure (top to bottom):

### App header section
- `RoundedRectangle` icon tile in `Replr.accent`, arrow icon in `Replr.accentFg`
- "Replr" title + "AI-powered reply keyboard" subtitle

### Keyboard section
- **Tones** — navigation row showing active tone name as trailing value. Navigates to `TonesView`. Tones tab is removed; `TonesView` becomes a pushed destination only.
- **Keep replies between sessions** — toggle (existing)

### AI Model section
- Inline picker: Claude (Anthropic) / GPT-4o (OpenAI) (existing)

### Memory section
- **Enable Memory** — prominent toggle at top of section. When off, the rows below are hidden and no summaries are written or sent to the LLM.
- **Time window** — picker: 7 days / 30 days / 90 days / All time (hidden when Memory off)
- **Conversations per contact** — picker: 5 / 10 / 20 (hidden when Memory off)

### Account section
- Subscription navigation link (existing)

### About section
- Version (existing)

---

## Tab 2: History

**File:** `Replr/Features/Captures/CaptureLogView.swift` → rename to `HistoryView.swift`

Timeline of captures, organised chronologically. Identical layout to the current Captures tab with one addition: contact chips show a `sparkles` SF Symbol indicator when that contact has memory built up (i.e. at least one LLM summary stored) AND Memory is enabled globally.

### Contact filter chips
- Tapping a chip filters the list to that contact (existing behaviour — unchanged).
- When Memory is enabled and the contact has at least one LLM summary: chip shows a small `sparkles` SF Symbol icon alongside the name.
- When a single contact is selected (list is filtered) AND Memory is enabled AND that contact has summaries: a "View Memory →" button appears in the filtered list header row, navigating to `ContactMemoryDetailView`.
- When Memory is disabled or contact has no summaries: no sparkles icon, no "View Memory" button.

### Capture rows
- Thumbnail, contact name, timestamp, summary, sent-reply indicator (existing, no changes)

### Capture detail
- Existing `CaptureDetailView` — no changes

---

## Memory Detail View

**File:** `Replr/Features/Summaries/ContactMemoryDetailView.swift` (already exists, use as-is)

Pushed from History when user taps a contact chip that has memory. Navigation title = contact display name. "Clear Memory" destructive button in toolbar. Chronological list of LLM summaries.

The standalone `SummariesView` (the current Memory tab) is removed. `ContactMemoryDetailView` is reused directly.

---

## Memory enable/disable behaviour

When **Enable Memory is toggled off:**
- `AppGroupService.shared.memoryEnabled` is set to `false`
- `GenerateReplyIntent` reads this flag and skips `recentSummaries()` — sends no `previousContext` to the LLM
- The LLM still returns a `SUMMARY:` line in its response and it is still stored in `CaptureSession.llmSummary` (history is preserved). Summaries are just not fed back as context while Memory is off.
- Existing summaries are not deleted — re-enabling Memory immediately makes them available again.

When **Enable Memory is toggled on:**
- `recentSummaries()` is called on the next capture and summaries are sent as `previousContext`

---

## Files changed

| File | Change |
|------|--------|
| `App/ReplrApp.swift` — `ContentView` | Remove Memory + Tones tabs. Keep Captures (→ History) + Settings. Reorder: Settings first. |
| `Features/Settings/SettingsView.swift` | Add Memory toggle. Add Tones navigation row. Conditionally show memory depth pickers. |
| `Features/Captures/CaptureLogView.swift` | Rename to `HistoryView`. Add sparkles indicator on contact chips. Make chip tappable to push `ContactMemoryDetailView` when memory exists. |
| `Features/Summaries/SummariesView.swift` | Remove — no longer a tab destination. `ContactMemoryDetailView` remains. |
| `Shared/AppGroupService.swift` | Add `memoryEnabled: Bool` flag (UserDefaults, default `true`). |
| `Intents/GenerateReplyIntent.swift` | Read `memoryEnabled` — skip `recentSummaries()` when false. |

---

## What does NOT change

- `TonesView` and `ToneBuilderView` — unchanged, just no longer a tab
- `ContactMemoryDetailView` — unchanged
- `CaptureDetailView` — unchanged
- All keyboard extension code — untouched
- `GenerateReplyIntent` logic other than the memory flag check
- Backend — no changes
