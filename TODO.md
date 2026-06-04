# Replr — Active TODOs

State: `main` @ 2026-06-04. Screenshot-capture **Phase 1 + Phase 2 shipped**. Revert point: tag `stable-2026-06-04-pre-capture-redesign`.

## Screenshot capture — shipped & remaining

**Shipped (Phase 1 + 2):** collapse → screenshot → "tap to generate" → replies (iOS 16.6+); spike proved keyboard Photos reads are cheap (~137 MB headroom); captured-ID tracking + opt-in batch cleanup (Settings → Screenshots, deletes only Replr's recorded screenshots, one iOS confirm); collapsed-strip "Looking for your screenshot…" + iOS-26-only "Full-Screen Previews" hint after 5 s; onboarding Photos-permission step + iOS-26 tip (marked Optional, no broken deep-link); spike UI removed; Regenerate now re-runs the latest captured screenshot.

**Remaining:**

- **Tips & Guidance tab (NEW — planned)** — a dedicated section/tab in the app collecting *all* guidance in one place, instead of cluttering onboarding: how screenshot capture works, the iOS-26 Full-Screen Previews toggle, tones/memory tips, and **Back Tap setup**. Optional/advanced guidance lives here.
  - **Back Tap discoverability (move into this tab).** Mechanism is intact — `GenerateReplyIntent` works, triple-tap still generates for anyone already set up — but it's currently **undiscoverable**: the onboarding `BackTapStep`/`InstallShortcutStep` screens are orphaned (referenced nowhere after Phase 2), the History "Finish setup" banner is gated on `backTapSkipped` (only ever set by the removed onboarding step → never shows now), and `replr://setup` isn't triggered in-app. Fix: a "Set up Back Tap" entry in this tab/Settings that opens the existing `BackTapSetupFullView` sheet. Then optionally delete the orphaned onboarding carousel (`BackTapStep`, `InstallShortcutStep`).
- **Deeper onboarding restructure** — Phase-2 onboarding was additive (Photos step + iOS-26 tip; existing steps untouched). A full restructure (reorder, remove the orphaned Shortcut/Back-Tap screens, relabel) still wants a design pass + device review.
- **Screenshot-clutter UX polish** — cleanup logic shipped; consider surfacing the pending count / confirmation copy nicely once tested on device.
- **Phase 3 (later):** slim-bar-as-default Chat state (replace the idle panel) so the capture bar is the resting state, per the original brainstorm.

## Onboarding redesign (SUPERSEDED by screenshot capture — keep for reference)

Approach: **static image crossfade** showing the path through Settings → Accessibility → Touch → Back Tap → Triple Tap → Replr Capture. 5–6 PNG screenshots of the key states, crossfaded with native SwiftUI animation.

Why static images over video/GIF:
- ~50–100 KB total (vs 500 KB MP4, vs 10+ MB GIF)
- Pixel-perfect — true 1x screenshots, no compression artifacts
- No media framework or third-party library needed
- Easy to overlay a circle + arrow on the row the user should tap, per frame
- Easy to update one frame at a time when iOS changes a single Settings screen

Capture the screenshots from the iOS Simulator: navigate to each state, ⌘S to save the simulator screen. Crop to the relevant portion if needed.

Recommended frames:
1. Settings root (Accessibility row highlighted)
2. Accessibility (Touch row highlighted)
3. Touch (Back Tap row highlighted)
4. Back Tap (Triple Tap row highlighted)
5. Triple Tap (Replr Capture row highlighted)
6. Success state (Replr Capture row with checkmark)

Implementation sketch (Swift):
```swift
struct SetupWalkthroughView: View {
    private let steps = ["setup-1", "setup-2", "setup-3", "setup-4", "setup-5", "setup-6"]
    @State private var currentIndex = 0

    var body: some View {
        ZStack {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, name in
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(idx == currentIndex ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: currentIndex)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                currentIndex = (currentIndex + 1) % steps.count
            }
        }
    }
}
```

Below the crossfade, render text steps in SwiftUI for accessibility (VoiceOver users + sighted users who want to re-read).

The rest of the onboarding visual direction (overall layout, components, identity) is open — decide alongside whatever design tool you use next.

## Quick wins (ship independently of the redesign)

### 1. Tone override bug — `GenerateReplyIntent`

The shortcut hardcodes "Friendly" as the Tone parameter, so user's selected tone in the keyboard is ignored. Fix in `Replr/Replr/Intents/GenerateReplyIntent.swift`:

```swift
// Before calling ReplyService.generateReplies(), replace `tone: tone.tone` with the App Group value:
let effectiveTone = AppGroupService.shared.readSelectedTone()
// ... then in the API call use `tone: effectiveTone` instead of `tone: tone.tone`
```

5 minute fix.

### 2. Starting credits + pack copy

Sonnet costs 8 credits per capture. New users start with 10 → exactly 1 free capture, hits paywall instantly.

- Bump starting credits to ~40 (5 free captures) in `CreditsManager.migrateIfNeeded()`
- Fix misleading copy in `CreditPacksView.swift` — currently says "1 credit = 1 reply suggestion" (wrong; it's 8 credits for 3 suggestions). Change to "8 credits per capture · 3 replies each"

15 minute fix.

### 3. IAPs for TestFlight purchases

IAPs at "Ready to Submit" status don't load in TestFlight. To enable:
1. App Store Connect → create new App Store version
2. Attach all 4 IAPs to that version
3. Submit for App Store Review (can withdraw before they reject)
4. Wait ~24h for Apple to approve
5. Once "Approved", they load in TestFlight automatically

## Backend-driven shortcut URL

Move `Constants.shortcutInstallURL` from a hardcoded string to a server-fetched value so the shortcut can be updated without an App Store release.

Spec:
- `GET /config` on the Cloudflare Worker backend, returns `{ shortcutInstallURL, minSupportedAppVersion, shortcutVersion }`
- Accepts optional `?appVersion=X.Y.Z` query param for backward compatibility
- Cache-Control header for Cloudflare edge caching
- New iOS `ConfigService` fetches lazily (only when needed), caches 24h in `AppGroupService`, falls back to hardcoded `Constants.fallbackShortcutInstallURL` on error
- Replace direct lookups in `OnboardingView.swift` (used in `InstallShortcutStep` and `BackTapSetupFullView`)

~half-day, isolated change.

## Platform constraints to remember

- **No deep-linking past top-level Settings.** `prefs:root=` and `App-Prefs:` URL schemes are private API, App Store rejection risk, broken on iOS 18+. Confirmed via deep research. `UIApplication.openSettingsURLString` is the only public API.
- **`extensionContext?.open()` from the keyboard is unreliable.** Silently ignored by iMessage, Instagram, etc. Don't design flows that depend on the keyboard opening the companion app via deep link.
- **iCloud Shortcuts distribution is safe.** Opening `https://www.icloud.com/shortcuts/...` from the app carries no review risk. The shortcut's contents (including any private URLs inside it) live on Apple's servers, not in the app binary.
- **`lastIntentFiredAt` in `AppGroupService`** is the reliable signal that Back Tap is working. Use it to confirm setup success.
