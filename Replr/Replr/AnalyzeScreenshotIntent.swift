import AppIntents

struct AnalyzeScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Analyze Screenshot"
    static var description = IntentDescription("Analyzes a chat screenshot and prepares reply suggestions in your Replr keyboard.")

    @Parameter(
        title: "Screenshot",
        description: "The chat screenshot to analyze",
        supportedTypeIdentifiers: ["public.image"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile?

    static var parameterSummary: some ParameterSummary {
        Summary("Analyze \(\.$screenshot)")
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
