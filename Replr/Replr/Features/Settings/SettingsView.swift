import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredModel") var preferredModel = "claude"
    @State private var persistReplies = AppGroupService.shared.persistReplies

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

                Section {
                    Toggle("Keep replies between sessions", isOn: $persistReplies)
                        .onChange(of: persistReplies) { newValue in
                            AppGroupService.shared.persistReplies = newValue
                        }
                } header: {
                    Text("Keyboard")
                } footer: {
                    Text("When enabled, your last generated replies stay visible the next time you open the keyboard.")
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
