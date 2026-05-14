import AppIntents

struct ToggleScrollCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Scroll Capture"
    static var description = IntentDescription("Use the scroll button in the Replr keyboard to capture long conversations.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        return .result(value: "Open the Replr keyboard and tap the scroll button to capture a long conversation.")
    }
}
