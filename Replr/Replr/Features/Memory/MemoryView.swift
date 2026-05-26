import SwiftUI
import Combine

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
        for contact in contacts { AppGroupService.shared.clearMemory(forContactID: contact.id) }
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
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Memory-off warning
                            if !memoryEnabled {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 15))
                                        .foregroundStyle(ReplrTheme.Color.accent)
                                    Text("Memory is off. Enable it in Settings → Memory to use past context in future replies.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                                        .lineSpacing(2)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ReplrTheme.Color.accentSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                                        .strokeBorder(ReplrTheme.Color.accent.opacity(0.25), lineWidth: 1)
                                )
                            }

                            // Contact cards
                            VStack(spacing: 10) {
                                ForEach(vm.contacts) { contact in
                                    NavigationLink(
                                        destination: ContactMemoryDetailView(
                                            contact: contact,
                                            onClearMemory: { vm.clearMemory(for: contact) }
                                        )
                                    ) {
                                        contactCard(contact)
                                    }
                                    .buttonStyle(.plain)
                                    .background(ReplrTheme.Color.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                                            .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
                                    )
                                    .contextMenu {
                                        Button(role: .destructive) { vm.clearMemory(for: contact) } label: {
                                            Label("Clear Memory", systemImage: "brain.slash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .tint(ReplrTheme.Color.accent)
            .toolbar {
                if !vm.contacts.isEmpty {
                    Menu {
                        Button(role: .destructive) { vm.clearAll() } label: {
                            Label("Clear All Memory", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(ReplrTheme.Color.accent)
                    }
                }
            }
        }
        .onAppear {
            vm.load()
            memoryEnabled = AppGroupService.shared.memoryEnabled
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(ReplrTheme.Color.textSecondary)
            Text("No memory yet")
                .font(.headline)
            Text("Replr builds memory as you generate replies. Each contact gets a summary of your conversation history.")
                .font(.subheadline)
                .foregroundStyle(ReplrTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
    }

    // MARK: - Contact card content

    private func contactCard(_ contact: Contact) -> some View {
        HStack(spacing: 14) {
            // Avatar placeholder
            Circle()
                .fill(ReplrTheme.Color.accentSubtle)
                .frame(width: 42, height: 42)
                .overlay(
                    Text(String(contact.displayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                let count = vm.summaryCount(for: contact)
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(ReplrTheme.Color.accent)
                    Text("\(count) conversation\(count == 1 ? "" : "s") remembered")
                        .font(.system(size: 12))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.textTertiary)
        }
        .padding(14)
    }
}
