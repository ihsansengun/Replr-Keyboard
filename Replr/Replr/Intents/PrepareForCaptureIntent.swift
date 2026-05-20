import AppIntents

/// Signals the Replr keyboard to switch to the system keyboard so the
/// next "Take Screenshot" action captures the conversation, not the panel.
///
/// Add this as the first action in a Back Tap shortcut:
///   1. Switch to System Keyboard  ← this intent
///   2. Take Screenshot
///   3. Generate Reply
struct PrepareForCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch to System Keyboard"
    static var description = IntentDescription(
        "Switches from the Replr panel to the system keyboard so the next screenshot captures the conversation. Add before 'Take Screenshot' in your Back Tap shortcut."
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        AppGroupService.shared.setSwitchKeyboardRequested(true)
        // Give the keyboard extension time to poll the flag (0.25s loop) and animate the switch.
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return .result()
    }
}
