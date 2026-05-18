import Combine
import SwiftUI

// MARK: - View Model

struct ContactMemoryEntry: Identifiable {
    let contact: Contact
    let sessionCount: Int
    let lastSummary: String?
    let thumbnail: UIImage?

    var id: UUID { contact.id }
}

final class ContactMemoryViewModel: ObservableObject {
    @Published var entries: [ContactMemoryEntry] = []

    func load() {
        let contacts = AppGroupService.shared.loadContacts()
        entries = contacts.compactMap { contact in
            let sessions = AppGroupService.shared.sessions(forContactID: contact.id)
            let summaries = sessions.compactMap(\.llmSummary)
            guard !summaries.isEmpty else { return nil }
            let thumbnail = sessions.last?.thumbnailData.flatMap { UIImage(data: $0) }
            return ContactMemoryEntry(
                contact: contact,
                sessionCount: sessions.count,
                lastSummary: summaries.last,
                thumbnail: thumbnail
            )
        }
    }

    func clearMemory(for contact: Contact) {
        AppGroupService.shared.clearMemory(forContactID: contact.id)
        load()
    }
}

// MARK: - Main View

struct SummariesView: View {
    @StateObject private var vm = ContactMemoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "brain")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No memory yet")
                            .font(.headline)
                        Text("Replr builds a memory of each contact as you generate replies.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(vm.entries) { entry in
                            NavigationLink(destination: ContactMemoryDetailView(
                                contact: entry.contact,
                                onClearMemory: { vm.clearMemory(for: entry.contact) }
                            )) {
                                ContactMemoryRow(entry: entry)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Memory")
        }
        .onAppear { vm.load() }
    }
}

// MARK: - Row

struct ContactMemoryRow: View {
    let entry: ContactMemoryEntry
    private static let accent = Color.primary

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            if let img = entry.thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(
                        colors: [Self.accent.opacity(0.28), Self.accent.opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(entry.contact.displayName.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Self.accent)
                    )
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text(entry.contact.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.sessionCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Self.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Self.accent.opacity(0.14))
                        .clipShape(Capsule())
                }
                if let summary = entry.lastSummary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail View

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
                        .foregroundStyle(.secondary)
                    if let summary = session.llmSummary {
                        Text(summary)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }
        }
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
        if cal.isDateInToday(date) {
            return "Today · \(time)"
        } else if cal.isDateInYesterday(date) {
            return "Yesterday · \(time)"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
    }
}
