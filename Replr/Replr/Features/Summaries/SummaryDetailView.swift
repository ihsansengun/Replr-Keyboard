import SwiftUI

struct SummaryDetailView: View {
    @State var summary: ConversationSummary
    var onSave: (ConversationSummary) -> Void

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $summary.personName)
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                TextField("Platform", text: $summary.platform)
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparator(.hidden)
            } header: {
                Text("Person")
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }

            Section {
                TextEditor(text: $summary.notes)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(ReplrTheme.Color.surface)
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparator(.hidden)
            } header: {
                Text("Context Notes")
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .tint(ReplrTheme.Color.accent)
        .navigationTitle(summary.personName)
        .toolbar {
            Button("Save") {
                summary.updatedAt = .now
                onSave(summary)
            }
        }
    }
}
