# Back Tap Onboarding Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current Back Tap onboarding step (text breadcrumb + unverifiable "Done →") with a 5-screen iOS Settings visual walkthrough and a live triple/double-tap confirmation via AppGroup polling.

**Architecture:** A new `BackTapStepView.swift` file holds the redesigned `BackTapStep` view and all its sub-views. An internal state enum (`preview(substep:)` / `confirm` / `success`) drives transitions. AppGroup stores two new keys: `backTapSetupStarted` (Bool) and `lastIntentFiredAt` (Date). `GenerateReplyIntent` writes the timestamp on every run; `BackTapStep` polls it on the confirm screen to auto-advance to success.

**Tech Stack:** SwiftUI, AppIntents, UserNotifications, UserDefaults (App Group), Xcode 16 / iOS 17+

---

## File Map

| Action | Path | Purpose |
|---|---|---|
| **Create** | `Replr/Replr/Features/Onboarding/BackTapStepView.swift` | All new Back Tap UI: sub-step iOS mockups, state machine, confirm, success |
| **Modify** | `Shared/Constants.swift` | Two new AppGroup key constants |
| **Modify** | `Shared/AppGroupService.swift` | Two new computed properties |
| **Modify** | `Replr/Replr/Intents/GenerateReplyIntent.swift` | Write `lastIntentFiredAt` timestamp in `perform()` |
| **Modify** | `Replr/Replr/Features/Onboarding/OnboardingView.swift` | Remove old `BackTapStep`, update coordinator, drop `onSkip` |

---

## Task 1: AppGroup infrastructure

**Files:**
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`
- Modify: `Replr/Replr/Intents/GenerateReplyIntent.swift`

- [ ] **Step 1.1 — Add two new constants to `Constants.swift`**

  In `Shared/Constants.swift`, add after the `backTapSkippedKey` line:

  ```swift
  static let backTapSetupStartedKey     = "back_tap_setup_started"
  static let lastIntentFiredAtKey        = "last_intent_fired_at"
  ```

- [ ] **Step 1.2 — Add two new properties to `AppGroupService.swift`**

  In `Shared/AppGroupService.swift`, add after the `backTapSkipped` block (around line 109):

  ```swift
  // MARK: - Back Tap setup progress (written by companion onboarding, polled on confirm screen)

  var backTapSetupStarted: Bool {
      get { defaults.bool(forKey: Constants.backTapSetupStartedKey) }
      set { defaults.set(newValue, forKey: Constants.backTapSetupStartedKey); defaults.synchronize() }
  }

  var lastIntentFiredAt: Date? {
      get { defaults.object(forKey: Constants.lastIntentFiredAtKey) as? Date }
      set {
          if let v = newValue { defaults.set(v, forKey: Constants.lastIntentFiredAtKey) }
          else { defaults.removeObject(forKey: Constants.lastIntentFiredAtKey) }
          defaults.synchronize()
      }
  }
  ```

- [ ] **Step 1.3 — Write `lastIntentFiredAt` in `GenerateReplyIntent.perform()`**

  In `Replr/Replr/Intents/GenerateReplyIntent.swift`, add one line immediately after the `NSLog("[Replr][Intent] GenerateReplyIntent fired")` log on line 21:

  ```swift
  AppGroupService.shared.lastIntentFiredAt = Date()
  ```

  The top of `perform()` should now read:
  ```swift
  func perform() async throws -> some IntentResult {
      NSLog("[Replr][Intent] GenerateReplyIntent fired")
      AppGroupService.shared.lastIntentFiredAt = Date()
      // ... rest unchanged
  ```

- [ ] **Step 1.4 — Build in Xcode to verify no errors**

  Product → Build (⌘B). Expected: build succeeds, zero errors.

- [ ] **Step 1.5 — Commit**

  ```bash
  git add Shared/Constants.swift Shared/AppGroupService.swift \
    Replr/Replr/Intents/GenerateReplyIntent.swift
  git commit -m "feat: add backTapSetupStarted + lastIntentFiredAt AppGroup keys"
  ```

---

## Task 2: iOS Settings mockup shared components

**Files:**
- Create: `Replr/Replr/Features/Onboarding/BackTapStepView.swift`

These are the reusable building blocks that the 5 sub-step views all use.

- [ ] **Step 2.1 — Create `BackTapStepView.swift` with shared iOS mockup components**

  Create `Replr/Replr/Features/Onboarding/BackTapStepView.swift` with the following content:

  ```swift
  import SwiftUI
  import UserNotifications

  // MARK: - iOS Settings mockup palette (hardcoded to match real iOS dark UI)

  private enum IOSMock {
      static let bg           = Color.black
      static let cardBg       = Color(white: 0.11)   // #1c1c1e
      static let divider      = Color(white: 0.14)
      static let labelPrimary = Color.white
      static let labelSecondary = Color(white: 0.56) // #8e8e93
      static let backCircle   = Color(white: 0.17)   // #2c2c2e
      static let toggleOn     = Color(red: 0.20, green: 0.78, blue: 0.35) // iOS green
  }

  // MARK: - Shared sub-components

  private struct IOSNavBar: View {
      let title: String
      var showBack: Bool = true

      var body: some View {
          ZStack {
              if showBack {
                  HStack {
                      ZStack {
                          Circle()
                              .fill(IOSMock.backCircle)
                              .frame(width: 32, height: 32)
                          Image(systemName: "chevron.left")
                              .font(.system(size: 12, weight: .semibold))
                              .foregroundColor(.white)
                      }
                      Spacer()
                  }
                  .padding(.horizontal, 16)
              }
              Text(title)
                  .font(.system(size: 17, weight: .semibold))
                  .foregroundColor(.white)
          }
          .frame(height: 44)
          .background(IOSMock.bg)
      }
  }

  private struct IOSRowDivider: View {
      var body: some View {
          Rectangle()
              .fill(IOSMock.divider)
              .frame(height: 0.5)
              .padding(.leading, 16)
      }
  }

  private struct TapHereChip: View {
      var body: some View {
          Text("TAP HERE")
              .font(.system(size: 9, weight: .bold))
              .foregroundColor(ReplrTheme.Color.onAccent)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(ReplrTheme.Color.accent)
              .clipShape(Capsule())
      }
  }

  // Standard grouped-list row
  private struct IOSRow: View {
      let label: String
      var value: String? = nil
      var icon: String? = nil        // SF Symbol name
      var iconColor: Color = .blue
      var isHighlighted: Bool = false
      var showChevron: Bool = true
      var opacity: Double = 1.0

      var body: some View {
          HStack(spacing: 12) {
              if let icon {
                  ZStack {
                      RoundedRectangle(cornerRadius: 6, style: .continuous)
                          .fill(iconColor)
                          .frame(width: 28, height: 28)
                      Image(systemName: icon)
                          .font(.system(size: 14, weight: .medium))
                          .foregroundColor(.white)
                  }
              }
              Text(label)
                  .font(.system(size: 17))
                  .foregroundColor(isHighlighted ? ReplrTheme.Color.accent : IOSMock.labelPrimary)
              Spacer()
              if isHighlighted { TapHereChip() }
              if let value {
                  Text(value)
                      .font(.system(size: 17))
                      .foregroundColor(IOSMock.labelSecondary)
              }
              if showChevron {
                  Image(systemName: "chevron.right")
                      .font(.system(size: 13, weight: .semibold))
                      .foregroundColor(isHighlighted ? ReplrTheme.Color.accent : IOSMock.labelSecondary.opacity(0.5))
              }
          }
          .padding(.horizontal, 14)
          .frame(minHeight: 44)
          .background(isHighlighted ? ReplrTheme.Color.accent.opacity(0.09) : IOSMock.cardBg)
          .opacity(opacity)
      }
  }

  // Toggle row (used on Touch screen)
  private struct IOSToggleRow: View {
      let label: String
      var isOn: Bool = true
      var description: String? = nil
      var opacity: Double = 1.0

      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              HStack {
                  Text(label)
                      .font(.system(size: 17))
                      .foregroundColor(IOSMock.labelPrimary)
                  Spacer()
                  Capsule()
                      .fill(isOn ? IOSMock.toggleOn : Color(white: 0.23))
                      .frame(width: 48, height: 28)
                      .overlay(
                          Circle().fill(.white).frame(width: 24, height: 24)
                              .offset(x: isOn ? 10 : -10), alignment: .center
                      )
              }
              .padding(.horizontal, 14)
              .frame(minHeight: 44)
              if let description {
                  Text(description)
                      .font(.system(size: 13))
                      .foregroundColor(IOSMock.labelSecondary)
                      .padding(.horizontal, 14)
                      .padding(.bottom, 10)
              }
          }
          .background(IOSMock.cardBg)
          .opacity(opacity)
      }
  }

  // A card that wraps a single row (Touch screen style — each item is its own card)
  private struct IOSSoloCard<Content: View>: View {
      var isHighlighted: Bool = false
      var opacity: Double = 1.0
      @ViewBuilder var content: () -> Content

      var body: some View {
          content()
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              .overlay(
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .stroke(
                          isHighlighted ? ReplrTheme.Color.accent.opacity(0.45) : Color.clear,
                          lineWidth: 1.5
                      )
              )
              .padding(.horizontal, 16)
              .opacity(opacity)
      }
  }

  // A card that wraps multiple rows with internal dividers (Accessibility / Back Tap style)
  private struct IOSGroupCard<Content: View>: View {
      var opacity: Double = 1.0
      @ViewBuilder var content: () -> Content

      var body: some View {
          VStack(spacing: 0) { content() }
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              .padding(.horizontal, 16)
              .opacity(opacity)
      }
  }

  // Mini progress dots for sub-steps (e.g. ● ○ ○ ○ ○)
  private struct SubStepDots: View {
      let current: Int
      let total: Int

      var body: some View {
          HStack(spacing: 5) {
              ForEach(1...total, id: \.self) { i in
                  Capsule()
                      .fill(i == current ? ReplrTheme.Color.accent : ReplrTheme.Color.border)
                      .frame(width: i == current ? 16 : 6, height: 6)
              }
          }
      }
  }
  ```

- [ ] **Step 2.2 — Build in Xcode (⌘B) to confirm zero errors**

---

## Task 3: The 5 iOS Settings sub-step preview views

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/BackTapStepView.swift`

Each sub-step view shows a Replr instruction header and a simulated iOS Settings screen with the target row highlighted.

- [ ] **Step 3.1 — Add sub-step 1: Settings root → Accessibility**

  Append to `BackTapStepView.swift`:

  ```swift
  // MARK: - Sub-step 1: Settings root → Accessibility

  struct BackTapSubStep1: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              // Instruction header
              VStack(alignment: .leading, spacing: 6) {
                  SubStepDots(current: 1, total: 5)
                  Text("Open Settings, find Accessibility.")
                      .font(.system(size: 20, weight: .bold))
                      .foregroundColor(ReplrTheme.Color.textPrimary)
                  Text("Tap the back button if you see Replr's settings, then scroll to Accessibility.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .lineSpacing(2)
              }
              .padding(.horizontal, 24)
              .padding(.bottom, 16)

              // iOS Settings root mockup
              VStack(spacing: 0) {
                  Text("Settings")
                      .font(.system(size: 28, weight: .bold))
                      .foregroundColor(.white)
                      .frame(maxWidth: .infinity, alignment: .center)
                      .padding(.vertical, 10)
                      .background(IOSMock.bg)

                  IOSGroupCard {
                      IOSRow(label: "General",
                             icon: "gearshape.fill", iconColor: Color(white: 0.39),
                             opacity: 0.35)
                      IOSRowDivider()
                      IOSRow(label: "Accessibility",
                             icon: "accessibility", iconColor: Color(red: 0.04, green: 0.52, blue: 1.0),
                             isHighlighted: true)
                      IOSRowDivider()
                      IOSRow(label: "Action Button",
                             icon: "button.angledtop.vertical.right", iconColor: Color(white: 0.39),
                             opacity: 0.35)
                  }
              }
              .background(IOSMock.bg)
              .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
              .overlay(
                  RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                      .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
              )
              .padding(.horizontal, 24)
          }
      }
  }
  ```

- [ ] **Step 3.2 — Add sub-step 2: Accessibility → Touch**

  ```swift
  // MARK: - Sub-step 2: Accessibility → Touch

  struct BackTapSubStep2: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              VStack(alignment: .leading, spacing: 6) {
                  SubStepDots(current: 2, total: 5)
                  Text("Tap Touch.")
                      .font(.system(size: 20, weight: .bold))
                      .foregroundColor(ReplrTheme.Color.textPrimary)
                  Text("Under \"Physical and Motor\" — it's near the top of Accessibility.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .lineSpacing(2)
              }
              .padding(.horizontal, 24)
              .padding(.bottom, 16)

              VStack(spacing: 0) {
                  IOSNavBar(title: "Accessibility")

                  // Section header
                  Text("Physical and Motor")
                      .font(.system(size: 13))
                      .foregroundColor(IOSMock.labelSecondary)
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .padding(.horizontal, 32)
                      .padding(.top, 8)
                      .padding(.bottom, 4)
                      .background(IOSMock.bg)

                  IOSGroupCard {
                      IOSRow(label: "Touch",
                             icon: "hand.point.up.left.fill", iconColor: Color(red: 0.04, green: 0.52, blue: 1.0),
                             isHighlighted: true)
                      IOSRowDivider()
                      IOSRow(label: "Face ID & Attention",
                             icon: "faceid", iconColor: Color(red: 0.2, green: 0.78, blue: 0.35),
                             opacity: 0.35)
                      IOSRowDivider()
                      IOSRow(label: "Switch Control",
                             icon: "rectangle.grid.2x2.fill", iconColor: Color(white: 0.39),
                             value: "Off", opacity: 0.35)
                  }
              }
              .background(IOSMock.bg)
              .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
              .overlay(
                  RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                      .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
              )
              .padding(.horizontal, 24)
          }
      }
  }
  ```

- [ ] **Step 3.3 — Add sub-step 3: Touch → Back Tap**

  ```swift
  // MARK: - Sub-step 3: Touch → Back Tap

  struct BackTapSubStep3: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              VStack(alignment: .leading, spacing: 6) {
                  SubStepDots(current: 3, total: 5)
                  Text("Scroll down, tap Back Tap.")
                      .font(.system(size: 20, weight: .bold))
                      .foregroundColor(ReplrTheme.Color.textPrimary)
                  Text("It's its own card, about halfway down the Touch screen.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .lineSpacing(2)
              }
              .padding(.horizontal, 24)
              .padding(.bottom, 16)

              VStack(spacing: 0) {
                  IOSNavBar(title: "Touch")

                  ScrollView(showsIndicators: false) {
                      VStack(spacing: 10) {
                          // Solo cards (Touch screen uses individual cards per row)
                          IOSSoloCard(opacity: 0.35) {
                              IOSToggleRow(label: "Shake to Undo", isOn: true,
                                           description: "If you tend to shake your iPhone by accident…")
                          }
                          IOSSoloCard(opacity: 0.35) {
                              IOSToggleRow(label: "Vibration", isOn: true)
                          }
                          // Highlighted Back Tap card
                          IOSSoloCard(isHighlighted: true) {
                              VStack(alignment: .leading, spacing: 0) {
                                  IOSRow(label: "Back Tap", value: "On", isHighlighted: true)
                                  Text("Double- or triple-tap the back of your iPhone to perform actions quickly.")
                                      .font(.system(size: 13))
                                      .foregroundColor(ReplrTheme.Color.accent.opacity(0.7))
                                      .padding(.horizontal, 14)
                                      .padding(.bottom, 10)
                              }
                          }
                          IOSSoloCard(opacity: 0.35) {
                              IOSToggleRow(label: "Prefer Single-Touch Actions", isOn: false)
                          }
                      }
                      .padding(.vertical, 8)
                  }
                  .frame(maxHeight: 240)
              }
              .background(IOSMock.bg)
              .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
              .overlay(
                  RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                      .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
              )
              .padding(.horizontal, 24)
          }
      }
  }
  ```

- [ ] **Step 3.4 — Add sub-step 4: Back Tap → Double Tap**

  ```swift
  // MARK: - Sub-step 4: Back Tap → Double Tap

  struct BackTapSubStep4: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              VStack(alignment: .leading, spacing: 6) {
                  SubStepDots(current: 4, total: 5)
                  Text("Tap Double Tap.")
                      .font(.system(size: 20, weight: .bold))
                      .foregroundColor(ReplrTheme.Color.textPrimary)
                  Text("One less tap. Use Triple Tap instead if it misfires accidentally.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .lineSpacing(2)
              }
              .padding(.horizontal, 24)
              .padding(.bottom, 16)

              VStack(spacing: 0) {
                  IOSNavBar(title: "Back Tap")

                  VStack(spacing: 10) {
                      IOSGroupCard {
                          IOSRow(label: "Double Tap", value: "None", isHighlighted: true)
                          IOSRowDivider()
                          IOSRow(label: "Triple Tap", value: "None", opacity: 0.45)
                      }
                      IOSGroupCard(opacity: 0.35) {
                          IOSToggleRow(label: "Show Banner", isOn: true)
                      }
                  }
                  .padding(.vertical, 8)
              }
              .background(IOSMock.bg)
              .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
              .overlay(
                  RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                      .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
              )
              .padding(.horizontal, 24)
          }
      }
  }
  ```

- [ ] **Step 3.5 — Add sub-step 5: Double Tap list → select Replr Capture**

  ```swift
  // MARK: - Sub-step 5: Double Tap list → Replr Capture

  struct BackTapSubStep5: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              VStack(alignment: .leading, spacing: 6) {
                  SubStepDots(current: 5, total: 5)
                  Text("Scroll down, tap Replr Capture.")
                      .font(.system(size: 20, weight: .bold))
                      .foregroundColor(ReplrTheme.Color.textPrimary)
                  Text("Under Shortcuts — scroll down until you see Replr Capture. Then come back to this app.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .lineSpacing(2)
              }
              .padding(.horizontal, 24)
              .padding(.bottom, 16)

              VStack(spacing: 0) {
                  IOSNavBar(title: "Double Tap")

                  // Flat list (no grouped cards — this screen uses full-width rows)
                  VStack(spacing: 0) {
                      Text("Shortcuts")
                          .font(.system(size: 13))
                          .foregroundColor(IOSMock.labelSecondary)
                          .frame(maxWidth: .infinity, alignment: .leading)
                          .padding(.horizontal, 20)
                          .padding(.top, 8)
                          .padding(.bottom, 4)
                          .background(IOSMock.bg)

                      VStack(spacing: 0) {
                          flatRow("Quick Dictation to Clipboard", opacity: 0.3)
                          flatDivider()
                          flatRow("Quick Reply", opacity: 0.3)
                          flatDivider()
                          flatRow("Read Later", opacity: 0.3)
                          flatDivider()
                          // Target row
                          HStack {
                              Text("Replr Capture")
                                  .font(.system(size: 17))
                                  .foregroundColor(ReplrTheme.Color.accent)
                              TapHereChip()
                              Spacer()
                              Image(systemName: "checkmark")
                                  .font(.system(size: 14, weight: .semibold))
                                  .foregroundColor(ReplrTheme.Color.accent)
                          }
                          .padding(.horizontal, 20)
                          .frame(minHeight: 44)
                          .background(ReplrTheme.Color.accent.opacity(0.09))
                          flatDivider()
                          flatRow("…", opacity: 0.15)
                      }
                  }
                  .background(IOSMock.bg)

                  Text("↑ scroll up to find it")
                      .font(.system(size: 11))
                      .foregroundColor(IOSMock.labelSecondary.opacity(0.6))
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 6)
                      .background(IOSMock.bg)
              }
              .background(IOSMock.bg)
              .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
              .overlay(
                  RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                      .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
              )
              .padding(.horizontal, 24)
          }
      }

      private func flatRow(_ label: String, opacity: Double = 1.0) -> some View {
          Text(label)
              .font(.system(size: 17))
              .foregroundColor(IOSMock.labelPrimary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 20)
              .frame(minHeight: 44)
              .background(IOSMock.bg)
              .opacity(opacity)
      }

      private func flatDivider() -> some View {
          Rectangle()
              .fill(IOSMock.divider)
              .frame(height: 0.5)
              .padding(.leading, 20)
      }
  }
  ```

- [ ] **Step 3.6 — Build (⌘B), fix any errors**

- [ ] **Step 3.7 — Commit**

  ```bash
  git add Replr/Replr/Features/Onboarding/BackTapStepView.swift
  git commit -m "feat: add iOS Settings mockup sub-step views for Back Tap onboarding"
  ```

---

## Task 4: BackTapStep state machine, confirm screen, success screen, and notifications

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/BackTapStepView.swift`

- [ ] **Step 4.1 — Add notification helpers at the bottom of `BackTapStepView.swift`**

  Append to `BackTapStepView.swift`:

  ```swift
  // MARK: - Notification helpers

  private func scheduleBackTapReminder() {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
          guard granted else { return }
          let content = UNMutableNotificationContent()
          content.title = "Back Tap reminder"
          content.body = "Accessibility → Touch → Back Tap → Double Tap (or Triple Tap) → Replr Capture"
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 8, repeats: false)
          let request = UNNotificationRequest(
              identifier: "replr.backtap.reminder",
              content: content,
              trigger: trigger
          )
          UNUserNotificationCenter.current().add(request)
      }
  }

  private func cancelBackTapReminder() {
      UNUserNotificationCenter.current().removePendingNotificationRequests(
          withIdentifiers: ["replr.backtap.reminder"]
      )
  }
  ```

- [ ] **Step 4.2 — Add the confirm screen view**

  Append to `BackTapStepView.swift`:

  ```swift
  // MARK: - Confirm screen

  private struct BackTapConfirmScreen: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 16) {
              VStack(alignment: .leading, spacing: 6) {
                  Badge("Confirm")
                  Text("Test the gesture.")
                      .font(.system(size: 26, weight: .bold))
                      .tracking(-0.3)
                      .foregroundColor(ReplrTheme.Color.textPrimary)
                  Text("Tap the back of your phone now — double or triple, whichever you chose — to confirm it's wired up.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .lineSpacing(3)
              }

              VStack(spacing: 12) {
                  ZStack {
                      Circle()
                          .stroke(ReplrTheme.Color.accent.opacity(0.25), lineWidth: 1.5)
                          .frame(width: 80, height: 80)
                      Circle()
                          .stroke(ReplrTheme.Color.accent.opacity(0.1), lineWidth: 8)
                          .frame(width: 80, height: 80)
                      Image(systemName: "iphone.rear.camera")
                          .font(.system(size: 28))
                          .foregroundColor(ReplrTheme.Color.accent)
                  }
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 12)

                  Text("Tap-tap on the back of your phone. The app will react when it detects the gesture.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .multilineTextAlignment(.center)
                      .lineSpacing(3)
              }
              .padding(20)
              .background(ReplrTheme.Color.accent.opacity(0.06))
              .overlay(
                  RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                      .stroke(ReplrTheme.Color.accent.opacity(0.18), lineWidth: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
          }
      }
  }
  ```

- [ ] **Step 4.3 — Add the success screen view**

  Append to `BackTapStepView.swift`:

  ```swift
  // MARK: - Success screen

  private struct BackTapSuccessScreen: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 16) {
              VStack(alignment: .leading, spacing: 6) {
                  Badge("You're ready")
                  Text("Back Tap is live.")
                      .font(.system(size: 26, weight: .bold))
                      .tracking(-0.3)
                      .foregroundColor(ReplrTheme.Color.textPrimary)
                  Text("Tap from any chat. Replies appear in your keyboard instantly.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .lineSpacing(3)
              }

              VStack(spacing: 12) {
                  ZStack {
                      Circle()
                          .fill(ReplrTheme.Color.accent)
                          .frame(width: 72, height: 72)
                      Image(systemName: "checkmark")
                          .font(.system(size: 28, weight: .bold))
                          .foregroundColor(ReplrTheme.Color.onAccent)
                  }
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 12)

                  Text("Gesture confirmed! Replr is wired to your back tap — one gesture, from anywhere, forever.")
                      .font(ReplrTheme.Font.callout)
                      .foregroundColor(ReplrTheme.Color.textSecondary)
                      .multilineTextAlignment(.center)
                      .lineSpacing(3)
              }
              .padding(20)
              .background(ReplrTheme.Color.accent.opacity(0.06))
              .overlay(
                  RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                      .stroke(ReplrTheme.Color.accent.opacity(0.3), lineWidth: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
          }
      }
  }
  ```

- [ ] **Step 4.4 — Add the main `BackTapStep` state machine view**

  Append to `BackTapStepView.swift`:

  ```swift
  // MARK: - BackTapStep (main view — replaces the old BackTapStep in OnboardingView.swift)

  struct BackTapStep: View {
      let onNext: () -> Void
      let onBack: () -> Void

      enum SetupState: Equatable {
          case preview(substep: Int)
          case confirm
          case success
      }

      @State private var state: SetupState = .preview(substep: 1)
      @State private var confirmEnteredAt: Date?
      @Environment(\.scenePhase) private var scenePhase

      var body: some View {
          OnboardingStep(
              step: 3, totalSteps: 3,
              sectionLabel: sectionLabel,
              headline: headline,
              bodyText: bodyText,
              onBack: backAction
          ) {
              contentView
                  .padding(.bottom, 8)
          } cta: {
              ctaView
          }
          .onChange(of: scenePhase) { _, newPhase in
              handleScenePhaseChange(newPhase)
          }
          .onAppear {
              if AppGroupService.shared.backTapSetupStarted {
                  state = .confirm
                  confirmEnteredAt = Date()
              }
          }
          .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
              pollForIntentFire()
          }
      }

      // MARK: - Dynamic text

      private var sectionLabel: String {
          switch state {
          case .preview: return "Back Tap"
          case .confirm: return "Confirm"
          case .success: return "You're ready"
          }
      }

      private var headline: String {
          switch state {
          case .preview(let substep):
              switch substep {
              case 1: return "Open Settings, find Accessibility."
              case 2: return "Tap Touch."
              case 3: return "Scroll down, tap Back Tap."
              case 4: return "Tap Double Tap."
              default: return "Scroll down, tap Replr Capture."
              }
          case .confirm: return "Test the gesture."
          case .success: return "Back Tap is live."
          }
      }

      private var bodyText: String {
          switch state {
          case .preview(let substep):
              switch substep {
              case 1: return "Tap the back button if you see Replr's settings, then scroll to Accessibility."
              case 2: return "Under \"Physical and Motor\" — it's near the top of Accessibility."
              case 3: return "It's its own card, about halfway down the Touch screen."
              case 4: return "One less tap. Use Triple Tap instead if it misfires accidentally."
              default: return "Under Shortcuts — scroll down until you see Replr Capture. Then come back here."
              }
          case .confirm:
              return "Tap the back of your phone now — double or triple, whichever you chose — to confirm it's wired up."
          case .success:
              return "Tap from any chat. Replies appear in your keyboard instantly."
          }
      }

      // MARK: - Back navigation

      private var backAction: (() -> Void)? {
          switch state {
          case .preview(let substep):
              if substep == 1 { return onBack }
              return { state = .preview(substep: substep - 1) }
          case .confirm:
              return { state = .preview(substep: 5) }
          case .success:
              return nil
          }
      }

      // MARK: - Content

      @ViewBuilder
      private var contentView: some View {
          switch state {
          case .preview(let substep):
              Group {
                  switch substep {
                  case 1: BackTapSubStep1()
                  case 2: BackTapSubStep2()
                  case 3: BackTapSubStep3()
                  case 4: BackTapSubStep4()
                  default: BackTapSubStep5()
                  }
              }
              .transition(.asymmetric(
                  insertion: .move(edge: .trailing).combined(with: .opacity),
                  removal: .move(edge: .leading).combined(with: .opacity)
              ))
          case .confirm:
              BackTapConfirmScreen()
                  .transition(.opacity)
          case .success:
              BackTapSuccessScreen()
                  .transition(.opacity)
          }
      }

      // MARK: - CTA

      @ViewBuilder
      private var ctaView: some View {
          switch state {
          case .preview(let substep):
              if substep < 5 {
                  VStack(spacing: 12) {
                      PrimaryButton(label: "Next →") {
                          withAnimation(.easeInOut(duration: 0.25)) {
                              state = .preview(substep: substep + 1)
                          }
                      }
                  }
              } else {
                  // Sub-step 5: final preview — open Settings
                  VStack(spacing: 12) {
                      PrimaryButton(label: "Open Settings →") {
                          openSettings()
                      }
                      TertiaryButton(label: "Already set up →") {
                          state = .confirm
                          confirmEnteredAt = Date()
                      }
                  }
              }

          case .confirm:
              VStack(spacing: 12) {
                  TertiaryButton(label: "Skip for now →") {
                      cancelBackTapReminder()
                      AppGroupService.shared.backTapSetupStarted = false
                      onNext()
                  }
              }

          case .success:
              PrimaryButton(label: "Start using Replr →") {
                  onNext()
              }
          }
      }

      // MARK: - Actions

      private func openSettings() {
          AppGroupService.shared.backTapSetupStarted = true
          scheduleBackTapReminder()
          if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
          }
      }

      private func handleScenePhaseChange(_ newPhase: ScenePhase) {
          guard newPhase == .active,
                AppGroupService.shared.backTapSetupStarted,
                state != .success else { return }
          withAnimation {
              state = .confirm
              confirmEnteredAt = Date()
          }
      }

      private func pollForIntentFire() {
          guard state == .confirm,
                let entered = confirmEnteredAt,
                let fired = AppGroupService.shared.lastIntentFiredAt,
                fired > entered else { return }
          withAnimation {
              state = .success
          }
          cancelBackTapReminder()
          AppGroupService.shared.backTapSetupStarted = false
      }
  }
  ```

- [ ] **Step 4.5 — Build (⌘B), fix any errors**

- [ ] **Step 4.6 — Commit**

  ```bash
  git add Replr/Replr/Features/Onboarding/BackTapStepView.swift
  git commit -m "feat: BackTapStep state machine with confirm polling and local notification"
  ```

---

## Task 5: Update OnboardingView coordinator

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift`

- [ ] **Step 5.1 — Delete the old `BackTapStep` struct from `OnboardingView.swift`**

  Remove lines 381–459 in `OnboardingView.swift` (the entire `private struct BackTapStep` block). The new `BackTapStep` lives in `BackTapStepView.swift` and is no longer `private`.

- [ ] **Step 5.2 — Update `OnboardingView` coordinator to use new `BackTapStep`**

  The coordinator currently passes `onSkip` and has step 4 calling the old struct. Update the `case 4:` branch and remove the `onSkip` closure:

  Find this in `OnboardingView.body`:
  ```swift
  case 4:
      BackTapStep(
          onNext: { step = 0; onComplete() },
          onSkip: {
              AppGroupService.shared.backTapSkipped = true
              step = 0
              onComplete()
          },
          onBack: { step = 3 }
      )
  ```

  Replace with:
  ```swift
  case 4:
      BackTapStep(
          onNext: { step = 0; onComplete() },
          onBack: { step = 3 }
      )
  ```

- [ ] **Step 5.3 — Update the step guard**

  Find:
  ```swift
  .onAppear {
      if step > 4 { step = 0 }
  }
  ```

  No change needed — step 4 is still the Back Tap step index.

- [ ] **Step 5.4 — Build (⌘B), confirm zero errors**

- [ ] **Step 5.5 — Run on simulator and walk through the full flow**

  In Xcode, run the `Replr` target on an iPhone 15 simulator (iOS 17+).

  To test the onboarding, reset it:
  ```swift
  // In Xcode console (LLDB) after launch:
  // e UserDefaults.standard.set(0, forKey: "onboardingStep")
  // or delete the app and reinstall
  ```

  Verify:
  - Welcome → Keyboard → Full Access → Shortcut → Back Tap (step 03/03)
  - Sub-steps 1–5 animate forward/backward correctly
  - Sub-step 5 shows "Open Settings →" and "Already set up →"
  - Tapping "Already set up →" shows the confirm screen
  - Tapping "Skip for now →" on confirm completes onboarding
  - (On a real device) triggering Back Tap while on confirm screen auto-advances to success

- [ ] **Step 5.6 — Commit**

  ```bash
  git add Replr/Replr/Features/Onboarding/OnboardingView.swift
  git commit -m "feat: wire new BackTapStep into OnboardingView, remove old implementation"
  ```

---

## Self-review notes

- `BackTapStep` is exported (not `private`) from `BackTapStepView.swift` so `OnboardingView.swift` can reference it without any import — both are in the same module.
- `Badge`, `PrimaryButton`, `TertiaryButton`, `ReplrTheme` — all used from existing shared design system; no new dependencies.
- `OnboardingStep` wrapper is reused — the `headline` and `bodyText` params on that wrapper are now driven by the state machine, so the OnboardingStep chrome (step counter, progress bars, back button) renders correctly for all states.
- The `onBack` passed to `OnboardingStep` correctly returns `nil` on `.success` state (no back button shown when done).
- Notification cancellation happens on both skip and success paths — no orphaned pending notifications.
