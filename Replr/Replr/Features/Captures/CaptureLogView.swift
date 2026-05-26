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
            VStack(spacing: 0) {
                // Back-tap setup banner
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
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
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
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ReplrTheme.Color.accentSubtle)
                    .overlay(alignment: .bottom) {
                        ReplrTheme.Color.glassBorder.frame(height: 1)
                    }
                }

                if vm.sessions.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                        Text("No captures yet")
                            .font(.headline)
                        Text("Generate replies from the Replr keyboard to see them here.")
                            .font(.subheadline)
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
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
                            .padding(.vertical, 10)
                        }
                        ReplrTheme.Color.glassBorder.frame(height: 1)

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
                            ReplrTheme.Color.glassBorder.frame(height: 1)
                        }
                    }

                    List {
                        ForEach(vm.filteredSessions) { session in
                            NavigationLink(destination: CaptureDetailView(session: session)) {
                                CaptureRowView(session: session)
                            }
                            .listRowBackground(ReplrTheme.Color.surface)
                            .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                        }
                        .onDelete(perform: vm.delete)
                    }
                    .scrollContentBackground(.hidden)
                    .background(ReplrTheme.Color.bg)
                }
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .navigationTitle("Replies")
            .navigationBarTitleDisplayMode(.inline)
            .tint(ReplrTheme.Color.accent)
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
            .foregroundStyle(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .background(isSelected ? ReplrTheme.Color.accentSubtle : ReplrTheme.Color.surface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? ReplrTheme.Color.accent.opacity(0.55) : ReplrTheme.Color.glassBorder, lineWidth: 1))
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
                        .fill(ReplrTheme.Color.surfaceRaised)
                        .frame(width: 46, height: 80)
                        .overlay(
                            Image(systemName: "text.bubble")
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
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
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }

                if let summary = session.llmSummary {
                    Text(summary)
                        .font(.subheadline)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let selected = session.selectedReply {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ReplrTheme.Color.accent)
                        Text(selected)
                            .font(.caption)
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
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
                Section {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Screenshot")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
            }

            if let summary = session.llmSummary {
                Section {
                    Text(summary)
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Conversation Summary")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
            }

            if let hint = session.contextHint {
                Section {
                    Text(hint)
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                        .listRowBackground(ReplrTheme.Color.surface)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Context Provided")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }
            }

            Section {
                ForEach(session.generatedReplies, id: \.self) { reply in
                    HStack(alignment: .top, spacing: 12) {
                        Text(reply)
                            .foregroundStyle(ReplrTheme.Color.textPrimary)
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
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                    .animation(.spring(response: 0.25), value: copiedReply)
                            }
                            .buttonStyle(.plain)
                            if reply == session.selectedReply {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(ReplrTheme.Color.surface)
                    .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                }
            } header: {
                Text("Generated Replies")
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .tint(ReplrTheme.Color.accent)
        .navigationTitle(session.timestamp.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
