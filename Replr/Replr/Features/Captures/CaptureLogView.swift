import Combine
import SwiftUI
import UIKit

final class CaptureLogViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []
    @Published var selectedContactID: UUID? = nil  // nil = "All"

    @Published var allContacts: [Contact] = []

    var filteredSessions: [CaptureSession] {
        guard let id = selectedContactID else { return sessions }
        return sessions.filter { $0.contactID == id }
    }

    func load() {
        sessions = AppGroupService.shared.loadCaptureSessions().reversed()
        let ids = Set(sessions.compactMap(\.contactID))
        allContacts = AppGroupService.shared.loadContacts().filter { ids.contains($0.id) }
        // Reset stale filter if selected contact no longer has sessions
        if let sel = selectedContactID, !ids.contains(sel) {
            selectedContactID = nil
        }
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
                .lineLimit(1)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .frame(maxWidth: 160)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CaptureRowView: View {
    let session: CaptureSession
    private static let amber = Color(red: 0.961, green: 0.651, blue: 0.137)

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            Group {
                if let data = session.thumbnailData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 80)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 46, height: 80)
                        .overlay(
                            Image(systemName: "text.bubble")
                                .foregroundStyle(.secondary)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // Contact name + timestamp
                HStack(alignment: .center, spacing: 6) {
                    if let name = session.contactName {
                        Text(name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Self.amber)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(formattedTimestamp(session.timestamp))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                // Summary
                if let summary = session.llmSummary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Sent reply
                if let selected = session.selectedReply {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text(selected)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 6)
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

struct CaptureDetailView: View {
    let session: CaptureSession
    @State private var copiedReply: String? = nil
    private static let amber = Color(red: 0.961, green: 0.651, blue: 0.137)

    var body: some View {
        List {
            if let data = session.thumbnailData, let img = UIImage(data: data) {
                Section("Screenshot") {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    HStack(alignment: .top, spacing: 12) {
                        Text(reply)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(spacing: 8) {
                            Button {
                                UIPasteboard.general.string = reply
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.25)) { copiedReply = reply }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { if copiedReply == reply { copiedReply = nil } }
                                }
                            } label: {
                                Image(systemName: copiedReply == reply ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundStyle(copiedReply == reply ? Color.green : Self.amber)
                                    .animation(.spring(response: 0.25), value: copiedReply)
                            }
                            .buttonStyle(.plain)
                            if reply == session.selectedReply {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(session.timestamp.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
