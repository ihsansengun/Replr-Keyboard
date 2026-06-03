# Replr — Active TODOs

State: branch reverted to `a1a5151`. Codebase matches pre-redesign-attempt state.

## Onboarding redesign

Approach: **embed a real iOS Simulator screen recording** showing the navigation through Settings → Accessibility → Touch → Back Tap → Triple Tap → Replr Capture. Loop it inside the Back Tap setup card so users see the exact path they need to follow.

Reasons to use a real recording (not custom illustrations):
- Authentic — matches what users actually see on their device
- No ambiguity about which row to tap
- Trivial to update when iOS changes the Settings layout
- Easier to produce than custom animated diagrams

Implementation notes:
- Record on the iOS Simulator (Cmd+Ctrl+R in Simulator, or `xcrun simctl io booted recordVideo path.mov`)
- Export as a small looping `.mp4` or `.mov` (~5–10s, no audio)
- Embed in the onboarding view via `AVPlayerLayer` or `VideoPlayer` (iOS 14+)
- Set `videoGravity = .resizeAspectFill`, `isMuted = true`, loop indefinitely
- Show it inside a phone-frame device chrome for context, or full-bleed with overlay text

The rest of the onboarding visual direction is open — to be decided alongside whatever design tool you use next (Gemini didn't work).

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
