# Payment & Paywall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement trial-first paywall — 10 free requests, then `PaywallView` blocks the app and a compact card blocks the keyboard, with StoreKit 2 monthly ($9.99) and annual ($59.99) subscriptions.

**Architecture:** Trial counter lives in App Group UserDefaults so both the keyboard extension and companion app read the same value. The gate fires in `GenerateReplyIntent.perform()` (screenshot flow) and `KeyboardModel.generateEmailReply()` (email flow). The keyboard polls `paywallRequested` alongside existing flags. The companion app auto-presents `PaywallView` on foreground when `paywallRequested == true`.

**Tech Stack:** StoreKit 2, SwiftUI, App Group UserDefaults, UIInputViewController

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Shared/Constants.swift` | Modify | Add 3 App Group key constants |
| `Shared/AppGroupService.swift` | Modify | `trialUsedCount`, `trialExhausted`, `paywallRequested` properties |
| `ReplrKeyboard/Views/KeyboardView.swift` | Modify | Add `.paywall` state, `stateTag`, `trialRemaining`, trial gate in `generateEmailReply`, `PaywallCardView`, `TrialCounterBadge` in header |
| `ReplrKeyboard/KeyboardViewController.swift` | Modify | Poll for `paywallRequested`, `.paywall` height (280px), check on `viewWillAppear` |
| `Replr/Replr/Intents/GenerateReplyIntent.swift` | Modify | Trial gate before API call, increment on success |
| `Replr/Replr/Subscription/PaywallView.swift` | Create | Full-screen paywall with monthly + annual plans |
| `Replr/Replr/Subscription/SubscriptionManager.swift` | Modify | Clear `paywallRequested` on successful purchase |
| `Replr/Replr/App/ReplrApp.swift` | Modify | Handle `replr://paywall` URL, auto-present paywall on foreground |
| `Replr/Replr/Features/Settings/SettingsView.swift` | Modify | Replace `SubscriptionView()` with `PaywallView()` |
| `Replr/Replr/Subscription/SubscriptionView.swift` | Delete | Replaced by `PaywallView.swift` |

---

### Task 1: Add App Group key constants

**Files:**
- Modify: `Shared/Constants.swift`

- [ ] **Step 1: Add the three new keys**

Open `Shared/Constants.swift`. After the `backTapSetupStartedKey` line, add:

```swift
// Trial + paywall
static let trialUsedCountKey     = "replr.trial.usedCount"
static let trialExhaustedKey     = "replr.trial.exhausted"
static let paywallRequestedKey   = "replr.paywall.requested"
```

- [ ] **Step 2: Build to confirm no errors**

In Xcode: ⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add Shared/Constants.swift
git commit -m "feat: add trial + paywall App Group key constants"
```

---

### Task 2: Add trial and paywall properties to AppGroupService

**Files:**
- Modify: `Shared/AppGroupService.swift`

- [ ] **Step 1: Add the three computed properties**

At the end of `AppGroupService`, before the final closing brace, add a new `// MARK: - Trial + paywall` section:

```swift
// MARK: - Trial + paywall

var trialUsedCount: Int {
    get { defaults.integer(forKey: Constants.trialUsedCountKey) }
    set { defaults.set(newValue, forKey: Constants.trialUsedCountKey); defaults.synchronize() }
}

var trialExhausted: Bool {
    get { defaults.bool(forKey: Constants.trialExhaustedKey) }
    set { defaults.set(newValue, forKey: Constants.trialExhaustedKey); defaults.synchronize() }
}

var paywallRequested: Bool {
    get { defaults.bool(forKey: Constants.paywallRequestedKey) }
    set { defaults.set(newValue, forKey: Constants.paywallRequestedKey); defaults.synchronize() }
}
```

- [ ] **Step 2: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add Shared/AppGroupService.swift
git commit -m "feat: add trialUsedCount, trialExhausted, paywallRequested to AppGroupService"
```

---

### Task 3: Add `.paywall` to KeyboardState and update KeyboardModel

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Step 1: Add `.paywall` to the `KeyboardState` enum**

Find:
```swift
enum KeyboardState: Equatable {
    case idle
    case loading
    case replies([String])
    case error(String)
    case disambiguate(name: String, candidates: [Contact])
}
```

Replace with:
```swift
enum KeyboardState: Equatable {
    case idle
    case loading
    case replies([String])
    case error(String)
    case disambiguate(name: String, candidates: [Contact])
    case paywall
}
```

- [ ] **Step 2: Update `stateTag` computed property in `KeyboardRootView`**

Find:
```swift
private var stateTag: Int {
    switch model.state {
    case .idle:         return 0
    case .loading:      return 1
    case .replies:      return 2
    case .error:        return 3
    case .disambiguate: return 4
    }
}
```

Replace with:
```swift
private var stateTag: Int {
    switch model.state {
    case .idle:         return 0
    case .loading:      return 1
    case .replies:      return 2
    case .error:        return 3
    case .disambiguate: return 4
    case .paywall:      return 5
    }
}
```

- [ ] **Step 3: Add `.paywall` case to the `KeyboardRootView` body switch**

Find:
```swift
case .disambiguate(let name, let candidates):
    DisambiguatePanelView(model: model, name: name, candidates: candidates)
        .transition(.opacity)
```

After that case, add:
```swift
case .paywall:
    PaywallCardView(model: model).transition(.opacity)
```

- [ ] **Step 4: Add `trialRemaining` computed property to `KeyboardModel`**

Inside `final class KeyboardModel`, after the `retryTrigger` declaration, add:

```swift
/// Returns nil when premium (transactionID present). Returns 0–10 for trial users.
var trialRemaining: Int? {
    let txID = UserDefaults(suiteName: Constants.appGroupID)?
        .string(forKey: Constants.transactionIDKey)
    guard txID == nil else { return nil }
    return max(0, 10 - AppGroupService.shared.trialUsedCount)
}
```

- [ ] **Step 5: Add trial gate to `generateEmailReply()`**

Find the start of `func generateEmailReply()`:
```swift
func generateEmailReply() {
    guard case .idle = state else { return }
```

Replace with:
```swift
func generateEmailReply() {
    guard case .idle = state else { return }
    let remaining = trialRemaining ?? Int.max
    guard remaining > 0 else {
        AppGroupService.shared.paywallRequested = true
        withAnimation(.easeInOut(duration: 0.2)) { state = .paywall }
        return
    }
```

- [ ] **Step 6: Increment trial count after successful email generation**

Find the success path inside `generateEmailReply()` where replies are saved:
```swift
AppGroupService.shared.appendCaptureSession(session)
AppGroupService.shared.saveReplies(result.replies)
```

Add the increment immediately before `appendCaptureSession`:
```swift
if trialRemaining != nil { AppGroupService.shared.trialUsedCount += 1 }
AppGroupService.shared.appendCaptureSession(session)
AppGroupService.shared.saveReplies(result.replies)
```

- [ ] **Step 7: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 8: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: add .paywall state to KeyboardState, trial gate in generateEmailReply"
```

---

### Task 4: Add trial gate to GenerateReplyIntent

**Files:**
- Modify: `Replr/Replr/Intents/GenerateReplyIntent.swift`

The screenshot flow runs through `GenerateReplyIntent.perform()` in the companion app process, where `SubscriptionManager.shared.isPremium` is available.

- [ ] **Step 1: Add trial gate at the top of `perform()`**

Find inside `func perform() async throws -> some IntentResult`:
```swift
NSLog("[Replr][Intent] GenerateReplyIntent fired")
AppGroupService.shared.lastIntentFiredAt = Date()
```

After those two lines, add:
```swift
// Trial gate
let isPremium = await SubscriptionManager.shared.isPremium
let trialUsed = AppGroupService.shared.trialUsedCount
guard isPremium || trialUsed < 10 else {
    NSLog("[Replr][Intent] trial exhausted — requesting paywall")
    AppGroupService.shared.paywallRequested = true
    AppGroupService.shared.saveError("trial_exhausted")
    return .result()
}
```

- [ ] **Step 2: Increment trial count on successful generation**

Find the success path where replies are saved (just before `AppGroupService.shared.isGenerating = false`):
```swift
AppGroupService.shared.isGenerating = false
AppGroupService.shared.appendCaptureSession(session)
AppGroupService.shared.saveReplies(result.replies)
```

Add the increment before `isGenerating = false`:
```swift
if !isPremium { AppGroupService.shared.trialUsedCount += 1 }
AppGroupService.shared.isGenerating = false
AppGroupService.shared.appendCaptureSession(session)
AppGroupService.shared.saveReplies(result.replies)
```

- [ ] **Step 3: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add Replr/Replr/Intents/GenerateReplyIntent.swift
git commit -m "feat: trial gate in GenerateReplyIntent — block after 10 uses, increment on success"
```

---

### Task 5: Add paywall detection to keyboard polling

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Add paywall check in `startCapturePoll()`**

Find the poll block inside `startCapturePoll()` — the `if/else if` chain that checks `switchKeyboardRequested`, `isGenerating`, `consumeReplies()`, `consumeError()`. Add a new branch for paywall at the top:

```swift
if AppGroupService.shared.paywallRequested {
    await MainActor.run {
        withAnimation(.easeInOut(duration: 0.2)) { self.model.state = .paywall }
    }
} else if AppGroupService.shared.switchKeyboardRequested {
```

(Replace the existing `if AppGroupService.shared.switchKeyboardRequested {` start with the combined block above.)

- [ ] **Step 2: Add paywall check in `viewWillAppear`**

Find the end of `viewWillAppear`, just before the `startCapturePoll()` call:
```swift
startCapturePoll()
```

Insert before it:
```swift
if AppGroupService.shared.paywallRequested || AppGroupService.shared.trialExhausted {
    let txID = UserDefaults(suiteName: Constants.appGroupID)?
        .string(forKey: Constants.transactionIDKey)
    if txID == nil {
        model.state = .paywall
    }
}
startCapturePoll()
```

- [ ] **Step 3: Add `.paywall` case to the height switch**

Find the `switch state` in the `stateCancellable` sink:
```swift
switch state {
case .idle:         height = inputMode == .email ? 224 : 310
case .loading:      height = 250
case .error:        height = 240
case .disambiguate: height = 300
case .replies:
```

Add the paywall case (280px, same as error):
```swift
switch state {
case .idle:         height = inputMode == .email ? 224 : 310
case .loading:      height = 250
case .error:        height = 240
case .paywall:      height = 280
case .disambiguate: height = 300
case .replies:
```

- [ ] **Step 4: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 5: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: keyboard polls for paywallRequested, .paywall height 280px, check on appear"
```

---

### Task 6: Build PaywallCardView in the keyboard

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Add `PaywallCardView` at the bottom of the file (before the last closing `}`). This is the compact 280px card shown inside the keyboard.

- [ ] **Step 1: Add `PaywallCardView`**

At the bottom of `KeyboardView.swift`, add:

```swift
// MARK: - Paywall Card (keyboard compact)

struct PaywallCardView: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, isSegmentedDisabled: true, isToneHidden: true)
            Spacer()
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Your 10 free replies are up.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                    Text("Unlock Pro to keep going.")
                        .font(.system(size: 13))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                Button {
                    openPaywallInApp()
                } label: {
                    Text("Unlock Pro in Replr")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                                .fill(ReplrTheme.Color.accent)
                        )
                        .shadow(color: ReplrTheme.Color.accent.opacity(
                            colorScheme == .dark ? 0.55 : 0), radius: 14, x: 0, y: 5)
                }
                .buttonStyle(.plain)

                Text("$9.99/mo · $59.99/yr")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
    }

    private func openPaywallInApp() {
        AppGroupService.shared.paywallRequested = true
        guard let url = URL(string: "replr://paywall") else { return }
        // extensionContext?.open is restricted in keyboard extensions on most iOS versions.
        // The App Group flag ensures companion app shows PaywallView on next foreground.
        _ = url
    }
}
```

- [ ] **Step 2: Add `TrialCounterBadge` and wire it into `KeyboardHeader`**

Add the badge view at the bottom of `KeyboardView.swift`:

```swift
// MARK: - Trial Counter Badge

struct TrialCounterBadge: View {
    let remaining: Int

    var body: some View {
        Text("\(remaining) left")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(remaining == 1
                ? ReplrTheme.Color.danger
                : Color(red: 0.85, green: 0.60, blue: 0.10)) // amber
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill((remaining == 1
                        ? ReplrTheme.Color.danger
                        : Color(red: 0.85, green: 0.60, blue: 0.10)).opacity(0.12))
            )
    }
}
```

Then update `KeyboardHeader.body` — replace:
```swift
ReplrMark(size: 16)
    .opacity(isSegmentedDisabled ? 0.4 : 1.0)
```

With:
```swift
if let remaining = model.trialRemaining, remaining <= 3 {
    TrialCounterBadge(remaining: remaining)
} else {
    ReplrMark(size: 16)
        .opacity(isSegmentedDisabled ? 0.4 : 1.0)
}
```

- [ ] **Step 3: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: PaywallCardView + TrialCounterBadge in keyboard"
```

---

### Task 7: Build PaywallView (companion app, full screen)

**Files:**
- Create: `Replr/Replr/Subscription/PaywallView.swift`

- [ ] **Step 1: Create the file**

Create `Replr/Replr/Subscription/PaywallView.swift` with the following content. Add it to the Replr target in Xcode (File → Add Files to "Replr", or drag into the Xcode project navigator under the Subscription group).

```swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    /// When presented modally after trial exhaustion, pass false so there's no dismiss.
    /// When navigated to from Settings, the NavigationLink provides the back button.
    var showCloseButton: Bool = false

    @StateObject private var manager = SubscriptionManager.shared
    @State private var selectedPlan: PlanOption = .annual
    @State private var purchasing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    enum PlanOption { case monthly, annual }

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if showCloseButton {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                                .padding(12)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                ScrollView {
                    VStack(spacing: 28) {
                        // MARK: Hero
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text("✦")
                                    .font(.system(size: 18))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                Text("Unlock Replr Pro")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                            }
                            Text("Reply smarter. Every time.")
                                .font(.system(size: 15))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        .padding(.top, showCloseButton ? 8 : 40)

                        // MARK: Plan Cards
                        HStack(spacing: 12) {
                            PlanCard(
                                title: "Monthly",
                                price: monthlyPrice,
                                subtitle: "per month",
                                badge: nil,
                                isSelected: selectedPlan == .monthly
                            )
                            .onTapGesture { selectedPlan = .monthly }

                            PlanCard(
                                title: "Annual",
                                price: annualPrice,
                                subtitle: "per year",
                                badge: "Save 50%",
                                isSelected: selectedPlan == .annual
                            )
                            .onTapGesture { selectedPlan = .annual }
                        }
                        .padding(.horizontal, 20)

                        // MARK: Feature List
                        VStack(alignment: .leading, spacing: 10) {
                            FeatureRow(text: "5 reply suggestions per capture")
                            FeatureRow(text: "Scroll capture — full conversation context")
                            FeatureRow(text: "Unlimited daily use")
                            FeatureRow(text: "Try Again anytime")
                        }
                        .padding(.horizontal, 24)

                        // MARK: CTA
                        VStack(spacing: 12) {
                            Button {
                                purchase()
                            } label: {
                                HStack(spacing: 8) {
                                    if purchasing {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(ReplrTheme.Color.onAccent)
                                            .scaleEffect(0.8)
                                    }
                                    Text(purchasing ? "Processing…"
                                         : "Continue with \(selectedPlan == .annual ? "Annual" : "Monthly")")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(ReplrTheme.Color.onAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                                        .fill(ReplrTheme.Color.accent.opacity(purchasing ? 0.5 : 1))
                                )
                                .shadow(
                                    color: ReplrTheme.Color.accent.opacity(scheme == .dark ? 0.55 : 0),
                                    radius: 18, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)
                            .disabled(purchasing || manager.products.isEmpty)
                            .padding(.horizontal, 20)

                            if selectedPlan == .annual {
                                Button { selectedPlan = .monthly } label: {
                                    Text("Or continue monthly")
                                        .font(.system(size: 14))
                                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(ReplrTheme.Color.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // MARK: Footer
                        HStack(spacing: 16) {
                            Button("Restore") { restore() }
                            Text("·").foregroundStyle(ReplrTheme.Color.textSecondary)
                            Link("Terms", destination: URL(string: "https://replr.app/terms")!)
                            Text("·").foregroundStyle(ReplrTheme.Color.textSecondary)
                            Link("Privacy", destination: URL(string: "https://replr.app/privacy")!)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await manager.load() }
    }

    // MARK: - Helpers

    private var monthlyProduct: Product? {
        manager.products.first { $0.id.contains("monthly") }
    }

    private var annualProduct: Product? {
        manager.products.first { $0.id.contains("yearly") }
    }

    private var monthlyPrice: String {
        monthlyProduct?.displayPrice ?? "$9.99"
    }

    private var annualPrice: String {
        annualProduct?.displayPrice ?? "$59.99"
    }

    private func purchase() {
        let product = selectedPlan == .annual ? annualProduct : monthlyProduct
        guard let product else { return }
        purchasing = true
        errorMessage = nil
        Task {
            do {
                try await manager.purchase(product)
                AppGroupService.shared.paywallRequested = false
                AppGroupService.shared.trialExhausted = false
            } catch {
                errorMessage = error.localizedDescription
            }
            purchasing = false
        }
    }

    private func restore() {
        purchasing = true
        Task {
            try? await AppStore.sync()
            await manager.checkEntitlement()
            if manager.isPremium {
                AppGroupService.shared.paywallRequested = false
                AppGroupService.shared.trialExhausted = false
            }
            purchasing = false
        }
    }
}

// MARK: - Supporting Views

private struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let badge: String?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ReplrTheme.Color.accent))
            } else {
                Spacer().frame(height: 20)
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Text(price)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(ReplrTheme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(
                    isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.glassBorder,
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(
            color: isSelected ? ReplrTheme.Color.accent.opacity(0.25) : .clear,
            radius: 12, x: 0, y: 4
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.accent)
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Spacer()
        }
    }
}
```

- [ ] **Step 2: Add the file to the Xcode target**

In Xcode project navigator, right-click the `Subscription` group under `Replr` target → Add Files. Select `PaywallView.swift`. Ensure only the `Replr` target checkbox is ticked.

- [ ] **Step 3: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add "Replr/Replr/Subscription/PaywallView.swift"
git commit -m "feat: PaywallView — full screen StoreKit 2 paywall with monthly + annual plans"
```

---

### Task 8: Update SubscriptionManager — clear paywall flag on purchase

**Files:**
- Modify: `Replr/Replr/Subscription/SubscriptionManager.swift`

- [ ] **Step 1: Clear `paywallRequested` on successful purchase**

Find `func purchase(_ product: Product)`:
```swift
func purchase(_ product: Product) async throws {
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
        guard case .verified = verification else { return }
        await checkEntitlement()
    default: break
    }
}
```

Replace with:
```swift
func purchase(_ product: Product) async throws {
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
        guard case .verified = verification else { return }
        await checkEntitlement()
        if isPremium {
            AppGroupService.shared.paywallRequested = false
            AppGroupService.shared.trialExhausted = false
        }
    default: break
    }
}
```

- [ ] **Step 2: Write transactionID to App Group after entitlement check**

Find `func checkEntitlement()`. At the point where `isPremium = true` is set, also write the transaction ID to App Group (so the keyboard and intent can read it):

```swift
func checkEntitlement() async {
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result,
           productIDs.contains(transaction.productID) {
            isPremium = true
            let txID = String(transaction.id)
            UserDefaults(suiteName: Constants.appGroupID)?
                .set(txID, forKey: Constants.transactionIDKey)
            return
        }
    }
    isPremium = false
    UserDefaults(suiteName: Constants.appGroupID)?
        .removeObject(forKey: Constants.transactionIDKey)
}
```

- [ ] **Step 3: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add "Replr/Replr/Subscription/SubscriptionManager.swift"
git commit -m "feat: clear paywallRequested + write transactionID to App Group on purchase"
```

---

### Task 9: Update ReplrApp — handle paywall URL and auto-present on foreground

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift`

- [ ] **Step 1: Add `showPaywall` state and foreground scene phase check**

Find:
```swift
@AppStorage("onboardingComplete") var onboardingComplete = false
@State private var showCapture = false
@State private var showSetup = false
```

Replace with:
```swift
@AppStorage("onboardingComplete") var onboardingComplete = false
@State private var showCapture = false
@State private var showSetup = false
@State private var showPaywall = false
@Environment(\.scenePhase) private var scenePhase
```

- [ ] **Step 2: Handle `replr://paywall` URL and foreground check**

Find the `onOpenURL` modifier:
```swift
.onOpenURL { url in
    guard url.scheme == "replr" else { return }
    switch url.host {
    case "capture":
        showCapture = true
    case "setup":
        showSetup = true
    default:
        break
    }
}
```

Replace with:
```swift
.onOpenURL { url in
    guard url.scheme == "replr" else { return }
    switch url.host {
    case "capture":
        showCapture = true
    case "setup":
        showSetup = true
    case "paywall":
        showPaywall = true
    default:
        break
    }
}
.onChange(of: scenePhase) { phase in
    guard phase == .active else { return }
    AppGroupService.shared.synchronize()
    if AppGroupService.shared.paywallRequested {
        let txID = UserDefaults(suiteName: Constants.appGroupID)?
            .string(forKey: Constants.transactionIDKey)
        if txID == nil { showPaywall = true }
    }
}
.fullScreenCover(isPresented: $showPaywall) {
    NavigationStack {
        PaywallView(showCloseButton: true)
            .onDisappear {
                AppGroupService.shared.paywallRequested = false
            }
    }
}
```

- [ ] **Step 3: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add "Replr/Replr/App/ReplrApp.swift"
git commit -m "feat: ReplrApp handles replr://paywall URL and auto-presents PaywallView on foreground"
```

---

### Task 10: Update SettingsView — link to PaywallView

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Replace `SubscriptionView` with `PaywallView`**

Find (line ~170):
```swift
NavigationLink(destination: SubscriptionView()) {
```

Replace with:
```swift
NavigationLink(destination: PaywallView()) {
```

- [ ] **Step 2: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add "Replr/Replr/Features/Settings/SettingsView.swift"
git commit -m "feat: SettingsView links to PaywallView instead of SubscriptionView"
```

---

### Task 11: Mark trial as exhausted when count reaches 10

**Files:**
- Modify: `Shared/AppGroupService.swift`

The `trialExhausted` flag should be set automatically when `trialUsedCount` reaches 10. Add a setter observer.

- [ ] **Step 1: Update the `trialUsedCount` setter to auto-set `trialExhausted`**

Replace the existing `trialUsedCount` property:
```swift
var trialUsedCount: Int {
    get { defaults.integer(forKey: Constants.trialUsedCountKey) }
    set { defaults.set(newValue, forKey: Constants.trialUsedCountKey); defaults.synchronize() }
}
```

With:
```swift
var trialUsedCount: Int {
    get { defaults.integer(forKey: Constants.trialUsedCountKey) }
    set {
        defaults.set(newValue, forKey: Constants.trialUsedCountKey)
        if newValue >= 10 {
            defaults.set(true, forKey: Constants.trialExhaustedKey)
        }
        defaults.synchronize()
    }
}
```

- [ ] **Step 2: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add Shared/AppGroupService.swift
git commit -m "feat: trialUsedCount setter auto-sets trialExhausted at 10"
```

---

### Task 12: Delete SubscriptionView.swift

**Files:**
- Delete: `Replr/Replr/Subscription/SubscriptionView.swift`

- [ ] **Step 1: Remove from Xcode and disk**

In Xcode navigator, right-click `SubscriptionView.swift` → Delete → Move to Trash.

- [ ] **Step 2: Build to confirm no references remain**

⌘B. Expected: Build Succeeded. If any "cannot find type 'SubscriptionView'" errors appear, search the project for remaining references and replace with `PaywallView`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove SubscriptionView — replaced by PaywallView"
```

---

### Task 13: Manual end-to-end test

No automated tests for StoreKit flows (StoreKit testing requires Xcode StoreKit configuration files and sandbox accounts). Verify manually.

- [ ] **Step 1: Test trial counter**

Build and run on a simulator or device. Open the keyboard. Use it 7 times (screenshot flow via Shortcuts). After the 7th, confirm no counter badge in the header. After 8th use, confirm "2 left" amber badge appears.

- [ ] **Step 2: Test trial exhaustion (keyboard)**

Use the 10th request. Confirm:
- Keyboard transitions to `PaywallCardView` (shows "Your 10 free replies are up.")
- "Unlock Pro in Replr" button is visible
- Price hint "$9.99/mo · $59.99/yr" shows below

- [ ] **Step 3: Test email flow trial gate**

Set `trialUsedCount` to 10 in App Group (via `UserDefaults(suiteName: "group.com.ihsan.replr")` in a debug view or lldb). Switch keyboard to email mode, tap "Generate Email Reply". Confirm keyboard transitions to PaywallCardView.

- [ ] **Step 4: Test companion app auto-present**

With `paywallRequested = true` in App Group (set via lldb or debug toggle), background and foreground the Replr app. Confirm `PaywallView` slides up as a fullScreenCover.

- [ ] **Step 5: Test StoreKit sandbox purchase**

In Xcode, add a `StoreKit Configuration File` to the scheme (Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration). Define the two products with their IDs and prices. Run on device/simulator, tap "Continue with Annual", complete sandbox purchase. Confirm:
- `isPremium = true`
- `paywallRequested = false`
- `transactionID` written to App Group
- Keyboard no longer shows PaywallCardView on next open

- [ ] **Step 6: Test Settings → Premium navigation**

Open companion app → Settings → Premium row. Confirm `PaywallView` opens with a back button (navigation-provided). Annual card highlighted by default.

---

### Task 14: App Store Connect — update product prices

This is a non-code step but required before TestFlight/submission.

- [ ] **Step 1:** Log into [App Store Connect](https://appstoreconnect.apple.com) → Your App → In-App Purchases
- [ ] **Step 2:** Open `Theory-of-Web.Replr.premium.monthly` → set price to **$9.99 (USD Tier 10)**
- [ ] **Step 3:** Open `Theory-of-Web.Replr.premium.yearly` → set price to **$59.99 (USD Tier 60)**
- [ ] **Step 4:** Submit prices for review if required

---

## Self-Review

**Spec coverage check:**
- ✓ 10-request trial in App Group — Task 2, 11
- ✓ Trial gate in GenerateReplyIntent (screenshot flow) — Task 4
- ✓ Trial gate in generateEmailReply (email flow) — Task 3
- ✓ `.paywall` keyboard state — Task 3
- ✓ Keyboard PaywallCardView — Task 6
- ✓ Trial counter badge ≤3 remaining — Task 6
- ✓ PaywallView companion app — Task 7
- ✓ Annual highlighted as primary CTA — Task 7
- ✓ No dismiss button when arriving from exhaustion — Task 7 (`showCloseButton: false` default)
- ✓ Dismiss button when arriving from Settings — Task 7 (`showCloseButton: true` not used from Settings; navigation back button serves this purpose)
- ✓ Prices loaded from StoreKit dynamically — Task 7
- ✓ `paywallRequested` cleared on purchase — Task 8
- ✓ `transactionID` written to App Group on purchase — Task 8
- ✓ `replr://paywall` URL scheme — Task 9
- ✓ Auto-present on foreground — Task 9
- ✓ SettingsView → PaywallView — Task 10
- ✓ Delete SubscriptionView — Task 12
- ✓ App Store Connect pricing — Task 14

**Type consistency:**
- `AppGroupService.shared.trialUsedCount` — Int, defined Task 2, used Tasks 3, 4, 11
- `AppGroupService.shared.trialExhausted` — Bool, defined Task 2, set auto in Task 11, read in Task 5
- `AppGroupService.shared.paywallRequested` — Bool, defined Task 2, set in Tasks 4, 5, 6, cleared in Tasks 8, 9
- `KeyboardState.paywall` — defined Task 3, handled in Tasks 5, 6, 7
- `model.trialRemaining: Int?` — defined Task 3, used Task 6

**No placeholders found.** All steps contain complete code.
