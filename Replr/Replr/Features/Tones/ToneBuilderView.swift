import SwiftUI

struct ToneBuilderView: View {
    var onSave: (Tone) -> Void
    @State private var name = ""
    @State private var instruction = ""
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
                        onSave(Tone(id: UUID(), name: name, instruction: instruction, isPreset: false, isEnabled: true))
                    }
                    .disabled(name.isEmpty || instruction.isEmpty)
                }
            }
        }
    }
}
