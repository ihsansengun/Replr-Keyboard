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
                // MARK: App identity
                Section {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                            .frame(width: 56, height: 56)
                            .overlay(
                                ReplrBirdShape()
                                    .fill(Color.white, style: FillStyle(eoFill: true))
                                    .frame(width: 34, height: 22)
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Replr")
                                .font(.title3.bold())
                            Text("Know what to say.")
                                .font(.subheadline)
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparator(.hidden)
                }

                // MARK: Keyboard
                Section {
                    NavigationLink(destination: TonesView().onDisappear {
                        activeToneName = AppGroupService.shared.readSelectedTone().name
                    }) {
                        LabeledContent("Tones", value: activeToneName)
                    }
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparatorTint(ReplrTheme.Color.glassBorder)

                    Toggle("Keep replies between sessions", isOn: $persistReplies)
                        .tint(ReplrTheme.Color.accent)
                        .onChange(of: persistReplies) { newValue in
                            AppGroupService.shared.persistReplies = newValue
                        }
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Keyboard")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                } footer: {
                    Text("When enabled, your last generated replies stay visible the next time you open the keyboard.")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                // MARK: AI Model
                Section {
                    Picker("Model", selection: $preferredModel) {
                        Text("Claude (Anthropic)").tag("claude")
                        Text("GPT-4o (OpenAI)").tag("gpt4o")
                    }
                    .pickerStyle(.inline)
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                } header: {
                    Text("AI Model")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                // MARK: Memory
                Section {
                    Toggle("Enable Memory", isOn: $memoryEnabled)
                        .tint(ReplrTheme.Color.accent)
                        .onChange(of: memoryEnabled) { AppGroupService.shared.memoryEnabled = $0 }
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparatorTint(ReplrTheme.Color.glassBorder)

                    if memoryEnabled {
                        Picker("Time window", selection: $memoryWindowDays) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("All time").tag(0)
                        }
                        .onChange(of: memoryWindowDays) { AppGroupService.shared.memoryWindowDays = $0 }
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparatorTint(ReplrTheme.Color.glassBorder)

                        Picker("Conversations per contact", selection: $memoryDepth) {
                            Text("5").tag(5)
                            Text("10").tag(10)
                            Text("20").tag(20)
                        }
                        .onChange(of: memoryDepth) { AppGroupService.shared.memoryDepth = $0 }
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Memory")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                } footer: {
                    Text("When enabled, Replr summarises each conversation and uses it as context when generating future replies for the same contact.")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                // MARK: Account
                Section {
                    NavigationLink("Subscription") { SubscriptionView() }
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Account")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                // MARK: About
                Section {
                    NavigationLink(destination: PrivacyView()) {
                        Label("Privacy", systemImage: "lock.shield")
                    }
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparatorTint(ReplrTheme.Color.glassBorder)

                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("About")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .tint(ReplrTheme.Color.accent)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
