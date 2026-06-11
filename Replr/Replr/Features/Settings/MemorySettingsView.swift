import SwiftUI
import Combine

final class MemorySettingsViewModel: ObservableObject {
    @Published var people: [Contact] = []

    func load() {
        let sessions = AppGroupService.shared.loadCaptureSessions()
        let idsWithMemory = Set(sessions.compactMap { s -> UUID? in
            guard s.llmSummary != nil, let id = s.contactID else { return nil }
            return id
        })
        people = AppGroupService.shared.loadContacts().filter { idsWithMemory.contains($0.id) }
    }

    func rememberedCount(for contact: Contact) -> Int {
        AppGroupService.shared.sessions(forContactID: contact.id)
            .filter { $0.llmSummary != nil }
            .count
    }

    func clearMemory(for contact: Contact) {
        AppGroupService.shared.clearMemory(forContactID: contact.id)
        load()
    }

    func clearAll() {
        for contact in people { AppGroupService.shared.clearMemory(forContactID: contact.id) }
        people = []
    }
}

/// Settings → Memory: the trust center. Toggle + retrieval knobs + everyone
/// Replr remembers, with per-person detail and clear-all.
struct MemorySettingsView: View {
    @StateObject private var vm = MemorySettingsViewModel()
    @State private var memoryEnabled = AppGroupService.shared.memoryEnabled
    @State private var memoryWindowDays = AppGroupService.shared.memoryWindowDays
    @State private var memoryDepth = AppGroupService.shared.memoryDepth
    @State private var showClearAllConfirm = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: "Memory") {
                    SettingsRow {
                        Text("Use memory").font(.system(size: 17))
                        Spacer()
                        BrandToggle(isOn: $memoryEnabled)
                            .onChange(of: memoryEnabled) { AppGroupService.shared.memoryEnabled = $0 }
                    }
                }
                Text("Replr keeps a short summary of each chat, per person, on your phone — so the next reply knows the story so far.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 4)

                if memoryEnabled {
                    SettingsCard(title: "Retrieval") {
                        SettingsRow {
                            Text("Time window").font(.system(size: 17))
                            Spacer()
                            SettingsMenuPicker(label: memoryWindowDays == 0 ? "All time" : "\(memoryWindowDays) days") {
                                Button("7 days") { memoryWindowDays = 7; AppGroupService.shared.memoryWindowDays = 7 }
                                Button("30 days") { memoryWindowDays = 30; AppGroupService.shared.memoryWindowDays = 30 }
                                Button("90 days") { memoryWindowDays = 90; AppGroupService.shared.memoryWindowDays = 90 }
                                Button("All time") { memoryWindowDays = 0; AppGroupService.shared.memoryWindowDays = 0 }
                            }
                        }
                        CardDivider()
                        SettingsRow {
                            Text("Chats per person").font(.system(size: 17))
                            Spacer()
                            SettingsMenuPicker(label: "\(memoryDepth)") {
                                Button("5") { memoryDepth = 5; AppGroupService.shared.memoryDepth = 5 }
                                Button("10") { memoryDepth = 10; AppGroupService.shared.memoryDepth = 10 }
                                Button("20") { memoryDepth = 20; AppGroupService.shared.memoryDepth = 20 }
                            }
                        }
                    }
                }

                if !vm.people.isEmpty {
                    if !memoryEnabled {
                        Text("Memory is off — Replr isn't saving new conversations. What's below is still stored until you clear it.")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                            .padding(.horizontal, 4)
                    }

                    SettingsCard(title: "People") {
                        ForEach(Array(vm.people.enumerated()), id: \.element.id) { idx, contact in
                            if idx > 0 { CardDivider() }
                            NavigationLink(destination: ContactMemoryDetailView(
                                contact: contact,
                                onClearMemory: { vm.clearMemory(for: contact) }
                            )) {
                                SettingsRow {
                                    Circle()
                                        .fill(ReplrTheme.Color.accentSubtle)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text(String(contact.displayName.prefix(1)).uppercased())
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(ReplrTheme.Color.accent)
                                        )
                                    Text(contact.displayName)
                                        .font(.system(size: 17))
                                        .lineLimit(1)
                                    Spacer()
                                    let n = vm.rememberedCount(for: contact)
                                    RowValue(text: "\(n) chat\(n == 1 ? "" : "s")")
                                    RowChevron()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button { showClearAllConfirm = true } label: {
                        Text("Clear all memory")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(ReplrTheme.Color.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 110)
            }
            .animation(ReplrTheme.Motion.quick, value: memoryEnabled)
            .padding(20)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .tint(ReplrTheme.Color.accent)
        .confirmationDialog("Clear memory for everyone?",
                            isPresented: $showClearAllConfirm, titleVisibility: .visible) {
            Button("Clear all memory", role: .destructive) {
                withAnimation(ReplrTheme.Motion.quick) { vm.clearAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replr forgets every remembered conversation. Reply history is kept.")
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refresh() }
        }
    }

    private func refresh() {
        AppGroupService.shared.synchronize()
        vm.load()
        memoryEnabled = AppGroupService.shared.memoryEnabled
        memoryWindowDays = AppGroupService.shared.memoryWindowDays
        memoryDepth = AppGroupService.shared.memoryDepth
    }
}
