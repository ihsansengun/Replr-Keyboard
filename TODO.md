# Replr — Active TODOs

State: `main` @ 2026-06-04. Screenshot-capture **Phase 1 shipped** (keyboard watches Photos → replies, no Back Tap). Revert point: tag `stable-2026-06-04-pre-capture-redesign`.

## Screenshot capture — Phase 2 (next)

Phase 1 (done): collapse keyboard → take screenshot → strip arms "tap to generate" → replies. Works on iOS 16.6+. Spike proved keyboard Photos reads are cheap (~137 MB headroom).

Remaining work:

- **Onboarding restructure** — make screenshot capture the primary taught flow. Demote Back Tap to optional/advanced (it still works; just not required). Drop the Shortcut-install + Accessibility steps from the required path.
- **iOS-version-aware setup tip** — on **iOS 26+ only**, show the one-toggle tip: Settings → Screen Capture → turn OFF "Full-Screen Previews" (otherwise screenshots don't auto-save and the watcher can't see them). iOS 16–18 auto-save by default → show nothing. Version is detectable; the setting value is not.
- **Adaptive "not detected" hint** — if user collapses + screenshots but nothing arms within ~5 s, surface "didn't catch that — check Full-Screen Previews." Safety net for the iOS 26 case.
- **Screenshot clutter mitigation** — the one real downside: captures pile up in Photos. Recommended: track captured `localIdentifier`s, offer a "Clear Replr screenshots (N)" bulk-delete button (one iOS confirmation). NOT per-capture auto-delete (iOS prompts per deletion → re-adds a tap).
- **"Looking for screenshot…" wait indicator** — the ~3 s auto-save delay should read as intentional in the collapsed strip.
- **Spike cleanup** — remove the keyboard 🔬 spike button, `runPhotosSpike`/`spikeResult`, and `PhotosCapture.run()`; replace the dev-screen "Request Photos Access" button with real onboarding permission UX. (Keep the `NSPhotoLibraryUsageDescription` fix.)
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
