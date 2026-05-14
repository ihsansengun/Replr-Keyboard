import SwiftUI

struct SummaryDetailView: View {
    @State var summary: ConversationSummary
    var onSave: (ConversationSummary) -> Void

    var body: some View {
        Form {
            Section("Person") {
                TextField("Name", text: $summary.personName)
                TextField("Platform", text: $summary.platform)
            }
            Section("Context Notes") {
                TextEditor(text: $summary.notes).frame(minHeight: 120)
            }
        }
        .navigationTitle(summary.personName)
        .toolbar {
            Button("Save") {
                summary.updatedAt = .now
                onSave(summary)
            }
        }
    }
}
