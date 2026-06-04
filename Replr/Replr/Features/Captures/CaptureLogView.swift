import Combine
import SwiftUI
import UIKit

final class RepliesViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []
    @Published var selectedContactID: UUID? = nil

    @Published var allContacts: [Contact] = []

    var filteredSessions: [CaptureSession] {
        guard let id = selectedContactID else { return sessions }
        return sessions.filter { $0.contactID == id }
    }

    func load() {
        sessions = AppGroupService.shared.loadCaptureSessions().reversed()
        let ids = Set(sessions.compactMap(\.contactID))
        allContacts = AppGroupService.shared.loadContacts().filter { ids.contains($0.id) }
        if let sel = selectedContactID, !ids.contains(sel) { selectedContactID = nil }
    }

    func clearAll() {
        AppGroupService.shared.clearCaptureSessions()
        sessions = []
        selectedContactID = nil
    }

    func deleteSession(_ session: CaptureSession) {
        var all = AppGroupService.shared.loadCaptureSessions()
        all.removeAll { $0.id == session.id }
        AppGroupService.shared.saveCaptureSessions(all)
        load()
    }

    func clearMemory(for contact: Contact) {
        AppGroupService.shared.clearMemory(forContactID: contact.id)
        load()
    }
}

// MARK: - Replies tab

struct RepliesView: View {
    @StateObject private var vm = RepliesViewModel()
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var memoryContact: Contact? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var backTapSkipped = AppGroupService.shared.backTapSkipped
    @State private var showSetupSheet = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Back-tap setup banner
                if backTapSkipped {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 15))
                            .foregroundStyle(ReplrTheme.Color.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Finish setup")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Set up Back Tap for one-gesture capture")
                                .font(.system(size: 12))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        Spacer()
                        Button("Set up") { showSetupSheet = true }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.accent)
                        Button {
                            AppGroupService.shared.backTapSkipped = false
                            backTapSkipped = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ReplrTheme.Color.accentSubtle)
                    .overlay(alignment: .bottom) {
                        ReplrTheme.Color.glassBorder.frame(height: 0.5)
                    }
                }

                if vm.sessions.isEmpty {
                    emptyState
                } else {
                    // Filter chips
                    if !vm.allContacts.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip(label: "All", id: nil)
                                ForEach(vm.allContacts) { c in
                                    filterChip(label: c.displayName, id: c.id)
                                        .contextMenu {
                                            Button(role: .destructive) { vm.clearMemory(for: c) } label: {
                                                Label("Clear Memory", systemImage: "brain.slash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        ReplrTheme.Color.glassBorder.frame(height: 0.5)
                    }

                    // Memory shortcut banner
                    if let id = vm.selectedContactID,
                       memoryEnabled,
                       let contact = vm.allContacts.first(where: { $0.id == id }),
                       contactHasMemory(id: id) {
                        Button { memoryContact = contact } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles").font(.system(size: 12))
                                Text("View Memory for \(contact.displayName)")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 11))
                            }
                            .foregroundStyle(ReplrTheme.Color.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(ReplrTheme.Color.accentSubtle)
                        }
                        .buttonStyle(.plain)
                        ReplrTheme.Color.glassBorder.frame(height: 0.5)
                    }

                    // Session cards
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filteredSessions) { session in
                                NavigationLink(destination: CaptureDetailView(session: session)) {
                                    CaptureRowView(session: session)
                                }
                                .buttonStyle(.plain)
                                .brandCard()
                                .contextMenu {
                                    Button(role: .destructive) { vm.deleteSession(session) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
            .navigationTitle("Replies")
            .navigationBarTitleDisplayMode(.inline)
            .tint(ReplrTheme.Color.accent)
            .toolbar {
                if !vm.sessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showClearConfirm = true
                        } label: {
                            Text("Clear all")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .alert("Clear all captures?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { vm.clearAll() }
            } message: {
                Text("This deletes all captured replies and conversation history. Memory paragraphs are kept.")
            }
            .sheet(isPresented: $showSetupSheet) {
                BackTapSetupFullView(isPresented: $showSetupSheet)
            }
        }
        .onAppear {
            AppGroupService.shared.synchronize()
            vm.load()
            memoryEnabled = AppGroupService.shared.memoryEnabled
            backTapSkipped = AppGroupService.shared.backTapSkipped
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            AppGroupService.shared.synchronize()
            vm.load()
            memoryEnabled = AppGroupService.shared.memoryEnabled
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

    // MARK: - Empty state

    private var emptyState: some View {
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
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter chip

    @ViewBuilder
    private func filterChip(label: String, id: UUID?) -> some View {
        let isSelected = vm.selectedContactID == id
        let showSparkles = id.map { contactHasMemory(id: $0) && memoryEnabled } ?? false
        Chip(
            label: label,
            isSelected: isSelected,
            icon: showSparkles ? "sparkles" : nil,
            action: { vm.selectedContactID = id }
        )
        .frame(maxWidth: 160)
    }

    private func contactHasMemory(id: UUID) -> Bool {
        AppGroupService.shared.sessions(forContactID: id).contains { $0.llmSummary != nil }
    }
}

// MARK: - Session row card content

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
                        .frame(width: 48, height: 82)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ReplrTheme.Color.surfaceRaised)
                        .frame(width: 48, height: 82)
                        .overlay(
                            Image(systemName: "text.bubble")
                                .font(.system(size: 18))
                                .foregroundStyle(ReplrTheme.Color.textTertiary)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    if let name = session.contactName {
                        HStack(spacing: 4) {
                            Text(name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ReplrTheme.Color.textPrimary)
                                .lineLimit(1)
                            if hasMemory {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                            }
                        }
                    }
                    Spacer()
                    Text(formattedTimestamp(session.timestamp))
                        .font(.system(size: 11))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }

                if let summary = session.llmSummary {
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if let tone = session.toneName {
                        HStack(spacing: 3) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9, weight: .semibold))
                            Text(tone)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(ReplrTheme.Color.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(ReplrTheme.Color.accentSubtle)
                        .clipShape(Capsule())
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

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.textTertiary)
        }
        .padding(14)
    }

    private var hasMemory: Bool {
        guard let id = session.contactID else { return false }
        return AppGroupService.shared.sessions(forContactID: id).contains { $0.llmSummary != nil }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if cal.isDateInToday(date) { return "Today · \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday · \(time)" }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

// MARK: - Capture detail

struct CaptureDetailView: View {
    let session: CaptureSession
    @State private var copiedReply: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let data = session.thumbnailData, let img = UIImage(data: data) {
                    detailSection("Screenshot") {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                if let summary = session.llmSummary {
                    detailSection("Conversation Summary") {
                        Text(summary)
                            .font(.system(size: 15))
                            .foregroundStyle(ReplrTheme.Color.textPrimary)
                            .lineSpacing(3)
                    }
                }

                // Capture intelligence
                HStack(spacing: 10) {
                    if let tone = session.toneName {
                        infoChip(icon: "waveform", label: tone)
                    }
                    if let model = session.modelUsed {
                        infoChip(icon: "cpu", label: model)
                    }
                    if let cost = session.costUsd {
                        infoChip(icon: "dollarsign.circle", label: String(format: "$%.4f", cost))
                    }
                }
                if let input = session.inputTokens, let output = session.outputTokens {
                    HStack(spacing: 10) {
                        infoChip(icon: "arrow.down.circle", label: "\(input) in")
                        infoChip(icon: "arrow.up.circle", label: "\(output) out")
                    }
                }

                if let hint = session.contextHint {
                    detailSection("Context Note") {
                        Text(hint)
                            .font(.system(size: 15))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                }

                if let memory = session.previousContext {
                    detailSection("Memory Fed to AI") {
                        Text(memory)
                            .font(.system(size: 14))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                            .lineSpacing(4)
                    }
                }

                detailSection("Generated Replies") {
                    VStack(spacing: 0) {
                        ForEach(Array(session.generatedReplies.enumerated()), id: \.offset) { idx, reply in
                            if idx > 0 {
                                ReplrTheme.Color.glassBorder.frame(height: 0.5).padding(.horizontal, 14)
                            }
                            HStack(alignment: .top, spacing: 12) {
                                Text(reply)
                                    .font(.system(size: 14))
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
                            .padding(14)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .navigationTitle(session.timestamp.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .tint(ReplrTheme.Color.accent)
    }

    @ViewBuilder
    private func infoChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(ReplrTheme.Color.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ReplrTheme.Color.surfaceRaised)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 4)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandCard()
        }
    }
}
