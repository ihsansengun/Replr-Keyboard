import SwiftUI

struct ToneBuilderView: View {
    var onSave: (Tone) -> Void
    @State private var name = ""
    @State private var instruction = ""
    /// Which keyboard modes show this tone. Email is opt-in — its professional
    /// register rarely fits a casual custom voice.
    @State private var modes: Set<String> = ["chat", "dating"]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Sarcastic, Chill, Direct", text: $name)
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Tone Name")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                Section {
                    TextEditor(text: $instruction)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .background(ReplrTheme.Color.surface)
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Describe your style")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                } footer: {
                    Text("Example: \"I'm dry, a bit sarcastic, never try-hard, and keep texts short.\"")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                Section {
                    modeToggle("Chat", key: "chat")
                    modeToggle("Dating", key: "dating")
                    modeToggle("Email", key: "email")
                } header: {
                    Text("Show in modes")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                } footer: {
                    Text("Email replies read very differently — only include this tone there if it fits that register.")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .tint(ReplrTheme.Color.accent)
            .navigationTitle("New Tone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Tone(id: UUID(), name: name, instruction: instruction,
                                    isPreset: false, isEnabled: true, modes: modes))
                    }
                    .disabled(name.isEmpty || instruction.isEmpty || modes.isEmpty)
                }
            }
        }
    }

    private func modeToggle(_ label: String, key: String) -> some View {
        Toggle(label, isOn: Binding(
            get: { modes.contains(key) },
            set: { on in if on { modes.insert(key) } else { modes.remove(key) } }
        ))
        .tint(ReplrTheme.Color.accent)
        .listRowBackground(ReplrTheme.Color.surface)
    }
}
