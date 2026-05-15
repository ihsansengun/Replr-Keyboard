import Combine
import SwiftUI

final class CaptureLogViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []
    @Published var selectedContactID: UUID? = nil  // nil = "All"

    var allContacts: [Contact] {
        let ids = Set(sessions.compactMap(\.contactID))
        return AppGroupService.shared.loadContacts().filter { ids.contains($0.id) }
    }

    var filteredSessions: [CaptureSession] {
        guard let id = selectedContactID else { return sessions }
        return sessions.filter { $0.contactID == id }
    }

    func load() {
        sessions = AppGroupService.shared.loadCaptureSessions().reversed()
    }

    func clearAll() {
        AppGroupService.shared.clearCaptureSessions()
        sessions = []
        selectedContactID = nil
    }

    func delete(at offsets: IndexSet) {
        let source = filteredSessions
        var all = AppGroupService.shared.loadCaptureSessions()
        let idsToRemove = Set(offsets.map { source[$0].id })
        all.removeAll { idsToRemove.contains($0.id) }
        AppGroupService.shared.saveCaptureSessions(all)
        load()
    }

    func clearMemory(for contact: Contact) {
        AppGroupService.shared.clearMemory(forContactID: contact.id)
        load()
    }
}

struct CaptureLogView: View {
    @StateObject private var vm = CaptureLogViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No captures yet")
                            .font(.headline)
                        Text("Generate replies from the Replr keyboard to see them here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Contact filter chips
                        if !vm.allContacts.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    filterChip(label: "All", id: nil)
                                    ForEach(vm.allContacts) { contact in
                                        filterChip(label: contact.displayName, id: contact.id)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    vm.clearMemory(for: contact)
                                                } label: {
                                                    Label("Clear Memory", systemImage: "brain.slash")
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            Divider()
                        }

                        List {
                            ForEach(vm.filteredSessions) { session in
                                NavigationLink(destination: CaptureDetailView(session: session)) {
                                    CaptureRowView(session: session)
                                }
                            }
                            .onDelete(perform: vm.delete)
                        }
                    }
                }
            }
            .navigationTitle("Captures")
            .toolbar {
                if !vm.sessions.isEmpty {
                    Button(role: .destructive) { vm.clearAll() } label: {
                        Text("Clear All")
                    }
                }
            }
        }
        .onAppear { vm.load() }
    }

    @ViewBuilder
    private func filterChip(label: String, id: UUID?) -> some View {
        let isSelected = vm.selectedContactID == id
        Button { vm.selectedContactID = id } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CaptureRowView: View {
    let session: CaptureSession

    var body: some View {
        HStack(spacing: 12) {
            if let data = session.thumbnailData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 36, height: 64)
                    .overlay(Image(systemName: "text.bubble").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(session.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let name = session.contactName {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let summary = session.llmSummary {
                    Text(summary)
                        .font(.subheadline)
                        .lineLimit(2)
                }

                if let selected = session.selectedReply {
                    Text("Sent: \(selected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CaptureDetailView: View {
    let session: CaptureSession

    var body: some View {
        List {
            Section("Screenshot") {
                if let data = session.thumbnailData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("No screenshot (email capture)")
                        .foregroundStyle(.secondary)
                }
            }

            if let summary = session.llmSummary {
                Section("Conversation Summary") {
                    Text(summary)
                }
            }

            if let hint = session.contextHint {
                Section("Context Provided") {
                    Text(hint)
                }
            }

            Section("Generated Replies") {
                ForEach(session.generatedReplies, id: \.self) { reply in
                    HStack {
                        Text(reply)
                        if reply == session.selectedReply {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.timestamp.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}
