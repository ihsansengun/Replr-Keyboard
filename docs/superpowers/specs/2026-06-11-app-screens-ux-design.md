# App screens UX redesign — Home / History / Settings

**Date:** 2026-06-11 · **Branch:** `app-screens` · **Status:** approved by owner (brainstorm 2026-06-11)

## Problem

Device pass confirmed four pains with the companion app:

1. **Settings is a wall** — nine sections in one scroll mixing appearance, setup,
   personalization, privacy, account, and about, with multi-paragraph explainers inline.
2. **No home / anchor** — the app opens on a history list; credits, setup state, and
   "what do I do next" are invisible.
3. **Replies tab unclear** — dense cards, unlabeled glyphs (sparkles, bare checkmark),
   no purpose or action on the screen.
4. **Memory/Replies overlap** — the same contacts appear in two tabs; memory *controls*
   live in Settings while memory *content* lives in the Memory tab.

Owner decisions during brainstorm: the app's job is **status + next action** (mission
control for the keyboard); scope is a **proper redesign** (IA may change); approach
chosen: **A — Home + History + Settings** (over B "People-led" and C "in-place tidy").

## Goals

- Give the app an anchor: a Home tab that answers "am I set up, how many replies do I
  have left, what happened recently, what do I tune".
- Make credits permanently glanceable with an in-flow low-balance state.
- Collapse the Memory/History duplication: memory becomes a property of a person.
- Turn Settings into a short, stateful root with sub-screens for anything wordy.
- Apply the owner's UX-taste rules: conventional placements, breathing room, no
  unlabeled glyphs, educate in place, copy matches reality.

## Non-goals

- No keyboard-extension changes, no backend changes, no new App Group keys or data
  migrations (everything reads existing `AppGroupService` / `CreditsManager` state).
- No paywall/product changes (entry points only).
- No onboarding changes (Home reuses the existing setup/tutorial flows).
- Visual identity unchanged — all styling via existing `ReplrTheme` tokens.

## Information architecture

```
Tabs:  Home (default) · History · Settings        (CustomTabBar: house / clock / gear)

Home      = setup card (conditional) + credits + how-it-works (until first capture)
            + recent replies + personalize tiles
History   = day-grouped capture sessions + contact filter chips + person header
            (chip selected) → memory sheet
Settings  = PERSONALIZE / KEYBOARD / PRIVACY & DATA / ACCOUNT + cold storage
Memory tab: deleted. Content splits into History's person header/sheet and
            Settings → Memory (trust center).
```

`TabSelection` becomes `.home / .history / .settings`; default `.home` on every launch.

## Screen: Home (new)

File: `Replr/Replr/Features/Home/HomeView.swift` (+ `HomeViewModel`). Own
`NavigationStack`, inline title "Replr".

Blocks, top to bottom (each hidden when not applicable):

1. **Setup card** — only while `!(fullAccessGranted && photosOK)` (same checks as
   `SetupStatusView`). Accent-bordered card, checklist rows (Keyboard & Full Access,
   Photos access) with check/circle icons, `PrimaryButton` "Finish setup" → existing
   `OnboardingView(startAtSetup: true)` sheet. The one loud element on the screen.
2. **Back Tap suggestion row** (only when setup card is gone, `backTapSkipped == true`):
   one quiet row "Back Tap: screenshot anywhere →" with dismiss ✕ (clears
   `backTapSkipped`), opens `BackTapSetupFullView`. Replaces the banner currently in
   RepliesView — that banner is removed.
3. **Credits card** — always. Big number (`CreditsManager.balanceDisplay`), "credits"
   caption, sub-line "≈ N replies" where
   `N = effectiveCreditBalance / AppGroupService.creditsRequired(for: userModel)`
   (round down). Trailing "Get more" → `CreditPacksView` push.
   - **Low state** (`balance < creditsRequired`, not dev mode): accent border, sub-line
     "Not enough for a reply", trailing button becomes primary "Top up".
   - **Dev mode**: shows ∞, no low state (mirrors keyboard).
4. **How Replr works card** — only while the user has zero capture sessions. Three
   numbered steps (reuse current empty-state copy), "Watch how →" opens
   `UsageTutorialView`. Disappears forever after the first session exists (tutorial
   stays reachable in Settings).
5. **Recent** — only when sessions exist. Header row "Recent" + "See all →" (switches
   the tab binding to `.history`). Last 3 sessions as light rows: contact name (or
   time when no contact), relative timestamp, one-line summary. No thumbnails, no
   chips. Tap → `CaptureDetailView` push.
6. **Personalize tiles** — two side-by-side tiles:
   - **Tone**: caption "Tone", value = active tone name. Opens `TonesView` sheet
     (same view the `replr://tones` deep link opens).
   - **About you**: caption "About you", value "Added ✓" / "Add". Opens the new
     `AboutYouView` editor (see Settings).

Data refresh mirrors today's tab behavior: reload on `onAppear` + `scenePhase == .active`
(`AppGroupService.synchronize()` first).

## Screen: History (rework of RepliesView)

Rename tab + title "Replies" → **"History"**. The type and file are renamed too:
`RepliesView` → `HistoryView`, `CaptureLogView.swift` → `HistoryView.swift`
(`CaptureRowView`/`CaptureDetailView` keep their names and file).

- **Day grouping**: sessions grouped under headers — "Today", "Yesterday", then
  absolute short dates ("Jun 9"). Grouping is a pure function of
  `session.timestamp` (unit-testable).
- **Filter chips**: unchanged behavior (All + contacts with sessions), but the
  sparkles glyph is dropped — chips are plain names.
- **Person header card** (new) — shown only when a contact chip is selected:
  avatar initial, name, "N replies · M chats remembered", trailing **Memory** pill
  button → `ContactMemoryDetailView` sheet. If global memory is **off**, the header
  shows "Memory is off — turn on in Settings" as the subtitle and the Memory pill
  opens the Memory settings sheet (`MemorySettingsView`, see below) instead.
  Replaces today's "View Memory for X" banner.
- **Cards** (`CaptureRowView`):
  - Title: contact name + time when unfiltered; **time only** when filtered to a
    contact (name would repeat on every card).
  - Sparkles next to the name: removed.
  - Bottom line: tone name (accent, keeps waveform glyph) and, when a reply was
    used, a labeled `Used: "…"` fragment instead of today's bare checkmark.
  - Thumbnail stays; placeholder becomes a lighter surface with a bubble icon.
  - Swipe-to-delete added (keeps the long-press context menu).
- **Toolbar**: "Clear all" pill replaced by a `⋯` menu containing "Clear all history"
  (destructive, same alert copy as today — memory paragraphs are kept).
- **Empty state**: simplified — icon, "Replies you generate show up here",
  "See how it works" tertiary button → tutorial. (Home teaches the steps now.)
- **Back Tap banner**: removed (moved to Home, block 2).

### CaptureDetailView (session detail)

- The `cpu` (model), `dollarsign` (cost), and token in/out chips render **only when
  `AppGroupService.devMode`** — users on quality tiers must never see vendor model
  names or dollar costs.
- Otherwise unchanged (screenshot, summary, context note, memory fed, replies + copy).

### ContactMemoryDetailView (memory sheet — kept, polished)

- Presented as a sheet from History's person header (and pushed from Settings →
  Memory's People list).
- Adds one explainer line under the title: "Replr remembers a short summary of each
  chat so future replies stay in context. Summaries only, stored on your phone."
- "Clear Memory" stays, moves to a destructive row at the bottom (not the toolbar).

## Screen: Settings (regrouped root + sub-screens)

Root sections in order (titles uppercase, current `settingsSection` style):

**PERSONALIZE**
| Row | Trailing state | Action |
|---|---|---|
| About you | "Added ✓" / "Add" | push `AboutYouView` |
| Tones | active tone name | push `TonesView` |
| Reply quality | inline 2-segment Balanced/Max | inline |

Reply-quality caption trims to one line: "Balanced 4 · Max 6 credits per reply."

**KEYBOARD**
| Row | Trailing | Action |
|---|---|---|
| Set up Replr | "All set ✓" (green) / "1 step left" (rose) | push `SetupStatusView` |
| Back Tap capture | › | sheet `BackTapSetupFullView` |
| How to use Replr | › | full-screen tutorial |
| Keep replies in keyboard | toggle | inline (`persistReplies`) |

"Keep replies in keyboard" gets subtitle "They stay until you generate new ones."

**PRIVACY & DATA**
| Row | Trailing | Action |
|---|---|---|
| Memory | "On"/"Off" | push `MemorySettingsView` (new) |
| Screenshots | "Auto-clear"/"Manual" | push `ScreenshotSettingsView` (new) |
| Privacy | › | push `PrivacyView` |

**ACCOUNT**
| Row | Trailing | Action |
|---|---|---|
| Credits | balance number | push `CreditPacksView` |
| email (secondary text) | "Sign out" (red, trailing button) | confirm + sign out |
| Delete account | — (red) | existing confirmation flow |

Order fixed: credits → sign out → delete; destructive last. (Today sign-out leads
the section.)

**Cold storage (bottom, no card emphasis)**
- Appearance: System/Light/Dark segmented (moved from the top — set-once setting).
- Version row (keeps the 1.5 s long-press → `ModelPickerView` dev gate).
- DEBUG: Replay onboarding row unchanged.

Deleted from root: identity card (logo + tagline — Home is the brand surface now),
About You inline textarea, Memory inline rows, Screenshots inline rows + paragraphs.

### New sub-screens

- **`AboutYouView`** — the 300-char free-text editor with example + privacy lines
  (copy unchanged from today's section), Done keyboard toolbar. Opened from Settings
  row and Home tile.
- **`MemorySettingsView`** — trust center:
  1. "Use memory" toggle (`memoryEnabled`) + explainer line (same copy as memory sheet).
  2. When on: "Time window" (7/30/90/All time) and "Chats per person" (5/10/20)
     menu pickers (renamed from "Conversations per contact").
  3. **PEOPLE** list: contacts that have ≥1 remembered summary, rows "name · N chats ›"
     → `ContactMemoryDetailView`; swipe-to-clear per person.
  4. "Clear all memory" destructive row + confirm (logic from old `MemoryViewModel.clearAll`).
  Presented pushed from Settings; also presentable as a sheet (History's memory-off hint).
- **`ScreenshotSettingsView`** — "Auto-clear captured screenshots" toggle,
  "Delete after each reply" toggle (with current subtitle), "Clear N captured
  screenshots" action row when pending > 0, the two existing explainer paragraphs,
  and the iOS 26 Full-Screen Previews tip (≥ iOS 26 only). All copy unchanged.

## Deletions / moves summary

| Today | After |
|---|---|
| Memory tab (`MemoryView`) | deleted — People list in `MemorySettingsView`; per-person sheet from History |
| "View Memory for X" banner (Replies) | person header card in History |
| Back Tap banner (Replies) | Home block 2 (dismissible row) |
| Settings identity card | deleted (Home shows the brand) |
| Settings About You textarea | `AboutYouView` (Settings push + Home tile) |
| Settings Memory rows | `MemorySettingsView` |
| Settings Screenshots rows + paragraphs | `ScreenshotSettingsView` |
| "Clear all" toolbar pill (Replies) | `⋯` menu in History |
| Cost/model/token chips (detail) | dev-mode-only |

## Files

New: `Features/Home/HomeView.swift`, `Features/Settings/AboutYouView.swift`,
`Features/Settings/MemorySettingsView.swift`, `Features/Settings/ScreenshotSettingsView.swift`.
Modified: `App/ReplrApp.swift` (ContentView tabs, default), `App/CustomTabBar.swift`
(labels/icons), `Features/Captures/CaptureLogView.swift` (History rework; renamed to
`HistoryView.swift`),
`Features/Summaries/ContactMemoryDetailView.swift` (explainer + bottom clear),
`Features/Settings/SettingsView.swift` (root regroup). Deleted:
`Features/Memory/MemoryView.swift`. The app folder is a synchronized group — new
files are picked up automatically.

## Edge cases

- **Dev mode**: credits card ∞, no low state; detail chips visible; everything else equal.
- **Zero balance**: Home credits card low state; existing `showPaywall` full-screen
  cover on activation is unchanged (they compose: cover shows first, card persists after).
- **Deep links**: `replr://setup|tutorial|paywall|tones|fullaccess` untouched — all
  present sheets/covers above ContentView regardless of selected tab.
- **Contact with no memory but sessions**: person header shows "N replies · nothing
  remembered yet"; Memory pill hidden.
- **All sessions for selected contact deleted**: existing reset-to-All logic kept.
- **History empty but setup incomplete**: History shows its simple empty state; the
  setup card lives on Home only.
- **iPad/landscape**: unchanged constraints — single column scroll views throughout.

## Testing

- Build gate: `xcodebuild … -scheme Replr` per CLAUDE.md.
- Unit (in `ReplrTests`): day-grouping function (Today/Yesterday/date buckets),
  credits→replies math incl. zero/dev cases, Home block visibility rules
  (setup/how-it-works/recent), person-header count strings.
- Existing tests must stay green (⌘U scheme `ReplrTests`).
- Manual device pass against the UX-taste checklist (clipping, containment,
  convention, air, stability, copy truth), dark **and** light.

## Out of scope / later

- Memory wedge part 2 (proactive "I remember [Name]" chip) — separate approved task.
- Screenshot primary-path work (task #88) — unaffected by this redesign.
- Any keyboard-extension UI changes.
