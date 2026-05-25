import SwiftUI

final class MemoryViewModel: ObservableObject {
    @Published var contacts: [Contact] = []

    func load() {
        let sessions = AppGroupService.shared.loadCaptureSessions()
        let idsWithMemory = Set(sessions.compactMap { s -> UUID? in
            guard s.llmSummary != nil, let id = s.contactID else { return nil }
            return id
        })
        contacts = AppGroupService.shared.loadContacts()
            .filter { idsWithMemory.contains($0.id) }
    }

    func summaryCount(for contact: Contact) -> Int {
        AppGroupService.shared.sessions(forContactID: contact.id)
            .filter { $0.llmSummary != nil }
            .count
    }

    func clearMemory(for contact: Contact) {
        AppGroupService.shared.clearMemory(forContactID: contact.id)
        load()
    }

    func clearAll() {
        for contact in contacts {
            AppGroupService.shared.clearMemory(forContactID: contact.id)
        }
        contacts = []
    }
}

struct MemoryView: View {
    @StateObject private var vm = MemoryViewModel()
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled

    var body: some View {
        NavigationStack {
            Group {
                if vm.contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "brain")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No memory yet")
                            .font(.headline)
                        Text("Replr builds memory as you generate replies. Each contact gets a summary of your conversation history.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !memoryEnabled {
                            Section {
                                Label(
                                    "Memory is off. Enable it in Settings → Memory to use past context in future replies.",
                                    systemImage: "exclamationmark.triangle"
                                )
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            }
                        }

                        Section {
                            ForEach(vm.contacts) { contact in
                                NavigationLink(
                                    destination: ContactMemoryDetailView(
                                        contact: contact,
                                        onClearMemory: { vm.clearMemory(for: contact) }
                                    )
                                ) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(contact.displayName)
                                                .font(.body.weight(.medium))
                                            let count = vm.summaryCount(for: contact)
                                            Text("\(count) conversation\(count == 1 ? "" : "s") remembered")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12))
                                            .foregroundStyle(ReplrTheme.Color.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !vm.contacts.isEmpty {
                    Menu {
                        Button(role: .destructive) { vm.clearAll() } label: {
                            Label("Clear All Memory", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            vm.load()
            memoryEnabled = AppGroupService.shared.memoryEnabled
        }
    }
}
