import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredModel") var preferredModel = "claude"

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Model") {
                    Picker("Model", selection: $preferredModel) {
                        Text("Claude (Anthropic)").tag("claude")
                        Text("GPT-4o (OpenAI)").tag("gpt4o")
                    }
                    .pickerStyle(.inline)
                }
                Section("Account") {
                    NavigationLink("Subscription") { SubscriptionView() }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
