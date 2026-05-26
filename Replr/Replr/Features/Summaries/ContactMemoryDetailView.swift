import SwiftUI

struct ContactMemoryDetailView: View {
    let contact: Contact
    var onClearMemory: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false

    private var sessions: [CaptureSession] {
        AppGroupService.shared.sessions(forContactID: contact.id)
            .filter { $0.llmSummary != nil }
            .reversed()
    }

    var body: some View {
        List {
            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 5) {
                    Text(formattedTimestamp(session.timestamp))
                        .font(.caption)
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                    if let summary = session.llmSummary {
                        Text(summary)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(ReplrTheme.Color.surface)
                .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .tint(ReplrTheme.Color.accent)
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button(role: .destructive) { showClearConfirm = true } label: {
                Text("Clear Memory")
            }
        }
        .confirmationDialog(
            "Clear all memory for \(contact.displayName)?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear Memory", role: .destructive) {
                onClearMemory()
                dismiss()
            }
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if cal.isDateInToday(date) { return "Today · \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday · \(time)" }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
