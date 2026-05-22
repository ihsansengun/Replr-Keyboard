import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredModel") var preferredModel = "claude"
    @State private var persistReplies = AppGroupService.shared.persistReplies
    @State private var memoryWindowDays = AppGroupService.shared.memoryWindowDays
    @State private var memoryDepth = AppGroupService.shared.memoryDepth
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var activeToneName = AppGroupService.shared.readSelectedTone().name

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(ReplrTheme.Color.onAccent)
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Replr")
                                .font(.title3.bold())
                            Text("AI-powered reply keyboard")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    NavigationLink(destination: TonesView().onDisappear {
                        activeToneName = AppGroupService.shared.readSelectedTone().name
                    }) {
                        LabeledContent("Tones", value: activeToneName)
                    }
                    Toggle("Keep replies between sessions", isOn: $persistReplies)
                        .onChange(of: persistReplies) { newValue in
                            AppGroupService.shared.persistReplies = newValue
                        }
                } header: {
                    Text("Keyboard")
                } footer: {
                    Text("When enabled, your last generated replies stay visible the next time you open the keyboard.")
                }

                Section("AI Model") {
                    Picker("Model", selection: $preferredModel) {
                        Text("Claude (Anthropic)").tag("claude")
                        Text("GPT-4o (OpenAI)").tag("gpt4o")
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Toggle("Enable Memory", isOn: $memoryEnabled)
                        .onChange(of: memoryEnabled) { AppGroupService.shared.memoryEnabled = $0 }
                    if memoryEnabled {
                        Picker("Time window", selection: $memoryWindowDays) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("All time").tag(0)
                        }
                        .onChange(of: memoryWindowDays) { AppGroupService.shared.memoryWindowDays = $0 }

                        Picker("Conversations per contact", selection: $memoryDepth) {
                            Text("5").tag(5)
                            Text("10").tag(10)
                            Text("20").tag(20)
                        }
                        .onChange(of: memoryDepth) { AppGroupService.shared.memoryDepth = $0 }
                    }
                } header: {
                    Text("Memory")
                } footer: {
                    Text("When enabled, Replr summarises each conversation and uses it as context when generating future replies for the same contact.")
                }

                Section("Account") {
                    NavigationLink("Subscription") { SubscriptionView() }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
