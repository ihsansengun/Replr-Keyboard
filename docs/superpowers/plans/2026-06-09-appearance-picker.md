# Appearance Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a System / Light / Dark appearance picker to the Replr companion app Settings screen.

**Architecture:** One `@AppStorage("colorSchemeAppearance")` key (String, default `"system"`) shared between `ReplrApp` and `SettingsView`. `ReplrApp` converts it to `ColorScheme?` and applies `.preferredColorScheme()` to the entire `WindowGroup` body via a wrapping `Group`. `SettingsView` gets a new "Appearance" section with a 3-segment custom control that writes to the same key — changes are immediately reflected in the whole app.

**Tech Stack:** SwiftUI, `@AppStorage` (standard UserDefaults), `ColorScheme`.

---

## Task 1: Wire the storage key and colour-scheme override in ReplrApp.swift

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift`

No unit-testable logic here — verification is manual (see step 4).

- [ ] **Step 1: Add the `@AppStorage` property and `resolvedScheme` computed var**

Open `Replr/Replr/App/ReplrApp.swift`. The struct currently begins:

```swift
@main
struct ReplrApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @StateObject private var authService = AuthService.shared
    ...
```

Add one line immediately after the existing `@AppStorage` line, and add the computed var after `applyBrandAppearance()`:

```swift
@main
struct ReplrApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @AppStorage("colorSchemeAppearance") private var colorSchemeAppearance = "system"  // ← ADD
    @StateObject private var authService = AuthService.shared
    @State private var signedIn: Bool = AuthService.shared.isSignedIn
    @State private var showCapture = false
    @State private var showSetup = false
    @State private var showPaywall = false
    @State private var showTutorial = false
    @State private var tutorialTopic: String? = nil
    @Environment(\.scenePhase) private var scenePhase

    // ↓ ADD this block after applyBrandAppearance() — before `var body`
    private var resolvedScheme: ColorScheme? {
        switch colorSchemeAppearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // nil = follow iOS system setting (the default)
        }
    }
```

- [ ] **Step 2: Wrap the WindowGroup body in a Group and apply `.preferredColorScheme`**

Find the `var body: some Scene` in `ReplrApp.swift`. It currently looks like:

```swift
var body: some Scene {
    WindowGroup {
        if !signedIn {
            SignInView(onSuccess: { signedIn = true })
                .environmentObject(authService)
        } else if !onboardingComplete {
            OnboardingView(onComplete: { onboardingComplete = true })
        } else {
            ContentView()
                .fullScreenCover(isPresented: $showCapture) { ... }
                // ... many modifiers
        }
    }
}
```

Wrap the three branches in `Group { }` and apply the modifier to the Group. **Do not change anything inside the branches — only add the wrapping Group:**

```swift
var body: some Scene {
    WindowGroup {
        Group {                                          // ← ADD
            if !signedIn {
                SignInView(onSuccess: { signedIn = true })
                    .environmentObject(authService)
            } else if !onboardingComplete {
                OnboardingView(onComplete: { onboardingComplete = true })
            } else {
                ContentView()
                    .fullScreenCover(isPresented: $showCapture) {
                        CaptureView(isPresented: $showCapture)
                    }
                    .sheet(isPresented: $showSetup) {
                        BackTapSetupFullView(isPresented: $showSetup)
                    }
                    .sheet(isPresented: $showTutorial) {
                        UsageTutorialView(startTopic: tutorialTopic, onDone: { showTutorial = false })
                    }
                    .onOpenURL { url in
                        guard url.scheme == "replr" else { return }
                        switch url.host {
                        case "capture":  showCapture = true
                        case "setup":    showSetup = true
                        case "tutorial":
                            tutorialTopic = url.path.isEmpty ? nil : url.lastPathComponent
                            showTutorial = true
                        case "paywall":  showPaywall = true
                        default:         break
                        }
                    }
                    .onChange(of: scenePhase) { phase in
                        guard phase == .active else { return }
                        AppGroupService.shared.synchronize()
                        CreditsManager.shared.refreshBalance()
                        if AppGroupService.shared.effectiveCreditBalance == 0 {
                            showPaywall = true
                        }
                        if AppGroupService.shared.autoClearScreenshots {
                            let threshold = AppGroupService.shared.deleteScreenshotAfterEach ? 1 : 5
                            if ScreenshotCleaner.pendingCount() >= threshold {
                                ScreenshotCleaner.clean()
                            }
                        }
                    }
                    .fullScreenCover(isPresented: $showPaywall) {
                        NavigationStack {
                            CreditPacksView(showCloseButton: true)
                        }
                    }
                    .onChange(of: authService.isSignedIn) { newValue in
                        if !newValue { signedIn = false }
                    }
            }
        }                                               // ← ADD (closes Group)
        .preferredColorScheme(resolvedScheme)           // ← ADD
    }
}
```

- [ ] **Step 3: Build and confirm no compiler errors**

In Xcode: **Product → Build** (⌘B). Expected: Build Succeeded with zero errors. The app should still launch identically — the scheme is `nil` (system default) until the user changes it in Settings.

- [ ] **Step 4: Manual smoke test**

Run the app on simulator or device. Because Settings hasn't changed yet, there's no UI to test — but confirm:
- App launches and behaves exactly as before ✓
- No visual change (still follows system appearance) ✓

- [ ] **Step 5: Commit**

```bash
git add Replr/Replr/App/ReplrApp.swift
git commit -m "feat: wire colorSchemeAppearance AppStorage + preferredColorScheme on root"
```

---

## Task 2: Add the Appearance section to SettingsView.swift

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Add `@AppStorage` to SettingsView's state block**

Open `Replr/Replr/Features/Settings/SettingsView.swift`. The `SettingsView` struct starts with a block of `@State` vars:

```swift
struct SettingsView: View {
    @State private var persistReplies = AppGroupService.shared.persistReplies
    @State private var memoryWindowDays = AppGroupService.shared.memoryWindowDays
    ...
    @FocusState private var aboutFocused: Bool
```

Add the `@AppStorage` property at the top of the state block, right after `struct SettingsView: View {`:

```swift
struct SettingsView: View {
    @AppStorage("colorSchemeAppearance") private var colorSchemeAppearance = "system"  // ← ADD
    @State private var persistReplies = AppGroupService.shared.persistReplies
    @State private var memoryWindowDays = AppGroupService.shared.memoryWindowDays
    @State private var memoryDepth = AppGroupService.shared.memoryDepth
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var activeToneName = AppGroupService.shared.readSelectedTone().name
    @State private var selectedModel = AppGroupService.shared.userModel
    @State private var showModelPicker = false
    @State private var autoClear = AppGroupService.shared.autoClearScreenshots
    @State private var deleteAfterEach = AppGroupService.shared.deleteScreenshotAfterEach
    @State private var pendingShots = ScreenshotCleaner.pendingCount()
    @State private var showTutorial = false
    @State private var showBackTapSetup = false
    @State private var preferredCapture = AppGroupService.shared.preferredCapture
    @State private var aboutUser = AppGroupService.shared.aboutUser
    @ObservedObject private var auth = AuthService.shared
    @FocusState private var aboutFocused: Bool
```

- [ ] **Step 2: Insert `appearanceSection` into the body VStack**

Find the `body` property. The inner VStack currently starts:

```swift
VStack(alignment: .leading, spacing: 24) {
    identityCard
    aboutYouSection
    keyboardSection
    aiModelSection
    memorySection
    screenshotSection
    accountSection
    aboutSection
    Spacer(minLength: 110)
}
```

Insert `appearanceSection` between `identityCard` and `aboutYouSection`:

```swift
VStack(alignment: .leading, spacing: 24) {
    identityCard
    appearanceSection    // ← ADD
    aboutYouSection
    keyboardSection
    aiModelSection
    memorySection
    screenshotSection
    accountSection
    aboutSection
    Spacer(minLength: 110)
}
```

- [ ] **Step 3: Add the `appearanceSection` computed property**

Find the `// MARK: - About You` comment in `SettingsView.swift`. Add the new section **above** it, after the `// MARK: - App identity` block ends:

```swift
// MARK: - Appearance

private var appearanceSection: some View {
    VStack(alignment: .leading, spacing: 4) {
        settingsSection("Appearance") {
            HStack(spacing: 0) {
                appearanceOption("system", icon: "iphone",  label: "System")
                ReplrTheme.Color.glassBorder.frame(width: 1, height: 58)
                appearanceOption("light",  icon: "sun.max", label: "Light")
                ReplrTheme.Color.glassBorder.frame(width: 1, height: 58)
                appearanceOption("dark",   icon: "moon",    label: "Dark")
            }
            .padding(6)
        }
        // Footnote sits outside the brandCard — same pattern as the Screenshots footnote
        Text("Overrides the system setting for Replr only.")
            .font(.system(size: 12))
            .foregroundStyle(ReplrTheme.Color.textSecondary)
            .padding(.horizontal, 4)
    }
}
```

- [ ] **Step 4: Add the `appearanceOption` helper**

Add immediately below `appearanceSection`. This helper mirrors `modelOption` exactly — same selected/unselected colours, same animation, same structure — but with an icon stacked above a label instead of a label + sublabel:

```swift
@ViewBuilder
private func appearanceOption(_ value: String, icon: String, label: String) -> some View {
    let isSelected = colorSchemeAppearance == value
    Button {
        colorSchemeAppearance = value
    } label: {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textPrimary)
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(isSelected ? ReplrTheme.Color.accentSubtle : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                .strokeBorder(
                    isSelected ? ReplrTheme.Color.accent.opacity(0.55) : Color.clear,
                    lineWidth: 1
                )
        )
    }
    .buttonStyle(.plain)
    .animation(ReplrTheme.Motion.quick, value: isSelected)
}
```

- [ ] **Step 5: Build**

**Product → Build** (⌘B). Expected: Build Succeeded, zero errors.

- [ ] **Step 6: Manual verification**

Run the app on simulator or device. Go to **Settings** (the gear tab).

Check the following:

1. **Appearance section visible** — it appears directly below the Replr logo card, above "About You". It shows a 3-segment control labelled "APPEARANCE" (uppercase section header) with System / Light / Dark segments and a footnote below.

2. **Default state** — "System" segment is highlighted with `accent` colour and `accentSubtle` background. Light and Dark are plain (`textPrimary`).

3. **Tap Light** — the whole app switches to light mode immediately, even if the device is in dark mode. The Light segment highlights.

4. **Tap Dark** — the whole app switches to dark mode immediately. Dark segment highlights.

5. **Tap System** — the app returns to following the device's own setting.

6. **Persistence** — set the mode to Dark, then force-quit the app and reopen it. The app should still be in dark mode and the Dark segment should still be highlighted.

7. **Both appearances** — verify in both dark and light mode that the Appearance card looks on-brand (accent colour for selected, `textPrimary` for unselected, `glassBorder` hairlines between segments).

- [ ] **Step 7: Commit**

```bash
git add Replr/Replr/Features/Settings/SettingsView.swift
git commit -m "feat: Appearance picker in Settings — System/Light/Dark"
```
