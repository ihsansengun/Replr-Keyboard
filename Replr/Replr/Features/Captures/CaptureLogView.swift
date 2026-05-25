import Combine
import SwiftUI
import UIKit

final class RepliesViewModel: ObservableObject {
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

struct RepliesView: View {
    @StateObject private var vm = RepliesViewModel()
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var memoryContact: Contact? = nil
    @State private var backTapSkipped = AppGroupService.shared.backTapSkipped
    @State private var showSetupSheet = false

    var body: some View {
        NavigationStack {
            if backTapSkipped {
                HStack(spacing: 12) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 16))
                        .foregroundStyle(ReplrTheme.Color.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Finish setup")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Set up Back Tap for one-gesture capture")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Set up") { showSetupSheet = true }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ReplrTheme.Color.accent)
                    Button {
                        AppGroupService.shared.backTapSkipped = false
                        backTapSkipped = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ReplrTheme.Color.accentSubtle)
            }

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
                            if let id = vm.selectedContactID,
                               memoryEnabled,
                               let contact = vm.allContacts.first(where: { $0.id == id }),
                               contactHasMemory(id: id) {
                                Button { memoryContact = contact } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12))
                                        Text("View Memory for \(contact.displayName)")
                                            .font(.system(size: 13, weight: .semibold))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(ReplrTheme.Color.accentSubtle)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
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
            .navigationTitle("Replies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !vm.sessions.isEmpty {
                    Button(role: .destructive) { vm.clearAll() } label: {
                        Text("Clear All")
                    }
                }
            }
            .sheet(isPresented: $showSetupSheet) {
                BackTapSetupFullView(isPresented: $showSetupSheet)
            }
        }
        .onAppear {
            vm.load()
            memoryEnabled = AppGroupService.shared.memoryEnabled
            backTapSkipped = AppGroupService.shared.backTapSkipped
        }
        .sheet(item: $memoryContact) { contact in
            NavigationStack {
                ContactMemoryDetailView(contact: contact, onClearMemory: {
                    AppGroupService.shared.clearMemory(forContactID: contact.id)
                    vm.load()
                    memoryContact = nil
                })
            }
        }
    }

    @ViewBuilder
    private func filterChip(label: String, id: UUID?) -> some View {
        let isSelected = vm.selectedContactID == id
        let hasMemory = id.map { contactHasMemory(id: $0) } ?? false
        let showSparkles = hasMemory && memoryEnabled
        Button { vm.selectedContactID = id } label: {
            HStack(spacing: 4) {
                Text(label)
                    .lineLimit(1)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                if showSparkles {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: 160)
            .background(isSelected ? ReplrTheme.Color.accent : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? ReplrTheme.Color.onAccent : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func contactHasMemory(id: UUID) -> Bool {
        AppGroupService.shared.sessions(forContactID: id).contains { $0.llmSummary != nil }
    }
}

struct CaptureRowView: View {
    let session: CaptureSession

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
                            .foregroundStyle(ReplrTheme.Color.accent)
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
                            .foregroundStyle(ReplrTheme.Color.success)
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
                                    .foregroundStyle(copiedReply == reply ? ReplrTheme.Color.success : ReplrTheme.Color.accent)
                                    .animation(.spring(response: 0.25), value: copiedReply)
                            }
                            .buttonStyle(.plain)
                            if reply == session.selectedReply {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ReplrTheme.Color.success)
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
