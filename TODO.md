# Replr — Active TODOs

State: `main` @ 2026-06-04. Screenshot-capture **Phase 1 + Phase 2 shipped**. Revert point: tag `stable-2026-06-04-pre-capture-redesign`.

## Screenshot capture — shipped & remaining

**Shipped (Phase 1 + 2):** collapse → screenshot → "tap to generate" → replies (iOS 16.6+); spike proved keyboard Photos reads are cheap (~137 MB headroom); captured-ID tracking + opt-in batch cleanup (Settings → Screenshots, deletes only Replr's recorded screenshots, one iOS confirm); collapsed-strip "Looking for your screenshot…" + iOS-26-only "Full-Screen Previews" hint after 5 s; onboarding Photos-permission step + iOS-26 tip (marked Optional, no broken deep-link); spike UI removed; Regenerate now re-runs the latest captured screenshot.

**Remaining:**

- **Tips & Guidance tab (NEW — planned)** — a dedicated section/tab in the app collecting *all* guidance in one place, instead of cluttering onboarding: how screenshot capture works, the iOS-26 Full-Screen Previews toggle, tones/memory tips, and **Back Tap setup**. Optional/advanced guidance lives here.
  - **Back Tap discoverability (move into this tab).** Mechanism is intact — `GenerateReplyIntent` works, triple-tap still generates for anyone already set up — but it's currently **undiscoverable**: the onboarding `BackTapStep`/`InstallShortcutStep` screens are orphaned (referenced nowhere after Phase 2), the History "Finish setup" banner is gated on `backTapSkipped` (only ever set by the removed onboarding step → never shows now), and `replr://setup` isn't triggered in-app. Fix: a "Set up Back Tap" entry in this tab/Settings that opens the existing `BackTapSetupFullView` sheet. Then optionally delete the orphaned onboarding carousel (`BackTapStep`, `InstallShortcutStep`).
- **Tip-show cadence — revisit (feature-discovery shipped 2026-06-06).** `KeyboardTipCoordinator` shows each tip (steer / Back Tap) up to 3× — one per keyboard *process* launch — then retires, or until ✕. Improve later: count per *session* not per process (iOS reuses the keyboard process, so two quick re-opens can read as one launch); add a cooldown so appearances are spaced, not consecutive; re-surface after N days if never engaged; tune thresholds (steer @ 2 captures / 2 regenerates, Back Tap @ 5 captures) from real usage. Also: the in-keyboard Back Tap tip is gated behind steer retiring + 5 captures, so it's hard to reach — add Back Tap to the revisitable usage tutorial so it's always discoverable (spec fallback B), and consider a dev affordance to force-trigger tips for testing. Knobs: `KeyboardTipCoordinator.maxSteerShows` / `maxBackTapShows`.
- **Status-aware onboarding flow** — only stop on steps that still need action. Signals already exist: `AppGroupService.keyboardInstalled`, `AppGroupService.fullAccessGranted`, `PHPhotoLibrary.authorizationStatus(for: .readWrite)`.
  - On launch, compute the first UNSATISFIED step and start there (today you must tap "Continue" through already-✓ steps).
  - Auto-advance any step already satisfied on entry. (Currently AddKeyboard/FullAccess only auto-advance when the permission flips *during* the step; PhotosPermissionStep always waits for a tap.)
  - If ALL satisfied → skip onboarding entirely (or a brief "you're all set" confirmation).
  - Show each step's ✓ granted state clearly.
- **Deeper onboarding restructure** — Phase-2 onboarding was additive (Photos step + iOS-26 tip; existing steps untouched). A full restructure (reorder, remove the orphaned Shortcut/Back-Tap screens, relabel) still wants a design pass + device review. Pairs with the status-aware flow above.
- **Screenshot-clutter UX polish** — cleanup logic shipped; consider surfacing the pending count / confirmation copy nicely once tested on device.
- **Phase 3 (later):** slim-bar-as-default Chat state (replace the idle panel) so the capture bar is the resting state, per the original brainstorm.

## Credits — persistence, recovery & hardening (revisit with the monetization review)

**Status:** chosen direction = server-authoritative ledger (recommendation **B**), phased.
**Defer the build** until the broader monetization review (model / cost / paywall) — plan +
bugs captured here. Today this is effectively **broken for paying users**.

**The problem.** Credits *and* `userID` both live in App Group UserDefaults, which iOS wipes
on app deletion. The backend has no credit ledger (rate-limit only). The consumable credit
packs (`com.ihsan.replr.credits.100/300/750/2500`) are **not** StoreKit-restorable. So on
reinstall or a new device a paying user loses their balance with **no recovery path**. The
balance is also client-writable today (a modified app could mint credits).

**Direction — B (server-authoritative), phased:**
- **Phase A (quick interim):** mirror the balance to iCloud (`NSUbiquitousKeyValueStore`),
  keyed to the Apple ID silently — survives reinstall + syncs across the user's devices, no
  sign-in, no backend. Caveat: client-trusted (a user could grant *themselves* credits;
  limited blast radius). Ships in hours.
- **Phase B (robust target):**
  - Stable anonymous `userID` in **iCloud-synced Keychain** (`kSecAttrSynchronizable`) —
    survives deletion + follows the Apple ID to new devices, no sign-in. (Today's UUID is in
    UserDefaults → lost on delete.)
  - **Server credit ledger** on the Worker (KV/D1) keyed to `userID`: balance / grant / deduct.
  - **Grant on verified purchase** — POST the StoreKit transaction (JWS) to the backend;
    verify via the App Store Server API; credit the ledger server-side.
  - **Deduct server-side** in `/reply`, so the balance is authoritative and un-forgeable.
  - App reads the balance from the server; recovery is automatic via the synced `userID`.
  - **Migrate** existing local balances to the server on first run (one-time reconcile).

**Folded-in fixes (do as part of B):**
- **Purchase-safety bug:** no `Transaction.updates` listener, so an *interrupted* purchase
  (Ask-to-Buy, network drop) can charge the user without granting credits. Add a listener
  that grants + finishes unfinished transactions on launch.
- **Dead buttons:** "I have an account" is a no-op (no auth) and "Restore Purchases"
  (`CreditPacksView`) is a no-op for consumables. Remove both — or, if the review picks
  **Approach C (Sign in with Apple)**, repurpose "I have an account" as the sign-in entry.

**Alternatives considered:** A (iCloud-only, client-trusted) · C (Sign in with Apple + server
ledger; explicit accounts, survives even a different Apple ID). Pick during the review.

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
