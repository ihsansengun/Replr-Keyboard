import SwiftUI

struct ToneBuilderView: View {
    var onSave: (Tone) -> Void
    @State private var name = ""
    @State private var instruction = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Tone Name") {
                    TextField("e.g. Sarcastic, Chill, Direct", text: $name)
                }
                Section {
                    TextEditor(text: $instruction).frame(minHeight: 100)
                } header: {
                    Text("Describe your style")
                } footer: {
                    Text("Example: \"I'm dry, a bit sarcastic, never try-hard, and keep texts short.\"")
                }
            }
            .navigationTitle("New Tone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Tone(id: UUID(), name: name, instruction: instruction, isPreset: false))
                    }.disabled(name.isEmpty || instruction.isEmpty)
                }
            }
        }
    }
}
