import SwiftUI
import Combine

final class TonesViewModel: ObservableObject {
    @Published var tones: [Tone] = []

    var presets: [Tone] { tones.filter(\.isPreset) }
    var custom: [Tone]  { tones.filter { !$0.isPreset } }

    /// Chat presets — the everyday set. Some also appear in Dating/Email (tagged in the row).
    var chatPresets: [Tone]   { tones.filter { $0.isPreset && Tone.chatToneNames.contains($0.name) } }
    /// Dating-only presets (the Settings "Dating" section).
    var datingPresets: [Tone] { tones.filter { $0.isPreset && Tone.datingOnlyToneNames.contains($0.name) } }
    /// Email-only presets — the professional register, strictly separate from chat.
    var emailPresets: [Tone]  { tones.filter { $0.isPreset && Tone.emailOnlyToneNames.contains($0.name) } }

    func load() { tones = AppGroupService.shared.readTones() }

    func save() { try? AppGroupService.shared.writeTones(tones) }

    func toggle(_ tone: Tone) {
        guard let idx = tones.firstIndex(where: { $0.id == tone.id }) else { return }
        tones[idx].isEnabled.toggle()
        save()
    }

    func add(_ tone: Tone) { tones.append(tone); save() }

    /// Reorder presets within a section (drag-to-reorder in Settings). Order persists
    /// and drives the keyboard row order. Storage layout: chat presets, then dating,
    /// then email, then custom tones.
    private func stitch(chat: [Tone], dating: [Tone], email: [Tone]) {
        tones = chat + dating + email + custom
        save()
    }

    func moveChatPresets(from source: IndexSet, to destination: Int) {
        var c = chatPresets
        c.move(fromOffsets: source, toOffset: destination)
        stitch(chat: c, dating: datingPresets, email: emailPresets)
    }

    func moveDatingPresets(from source: IndexSet, to destination: Int) {
        var d = datingPresets
        d.move(fromOffsets: source, toOffset: destination)
        stitch(chat: chatPresets, dating: d, email: emailPresets)
    }

    func moveEmailPresets(from source: IndexSet, to destination: Int) {
        var e = emailPresets
        e.move(fromOffsets: source, toOffset: destination)
        stitch(chat: chatPresets, dating: datingPresets, email: e)
    }

    func delete(at offsets: IndexSet) {
        let customTones = tones.filter { !$0.isPreset }
        let toDelete = offsets.map { customTones[$0] }
        tones.removeAll { t in toDelete.contains(where: { $0.id == t.id }) }
        save()
    }
}

struct TonesView: View {
    @StateObject private var vm = TonesViewModel()
    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.chatPresets) { tone in
                        PresetToneRow(tone: tone, onToggle: { vm.toggle(tone) },
                                      modeTags: sharedTags(for: tone),
                                      lockedOn: tone.name == "Natural")
                            .listRowBackground(ReplrTheme.Color.surface)
                            .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                    }
                    .onMove { vm.moveChatPresets(from: $0, to: $1) }
                } header: {
                    sectionHeader("Chat", enabled: vm.chatPresets.filter(\.isEnabled).count)
                } footer: {
                    Text("Tap the toggle to add or remove a tone from your keyboard. Tap Edit to reorder. Tones tagged Dating or Email also appear in those modes.")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                Section {
                    ForEach(vm.datingPresets) { tone in
                        PresetToneRow(tone: tone, onToggle: { vm.toggle(tone) })
                            .listRowBackground(ReplrTheme.Color.surface)
                            .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                    }
                    .onMove { vm.moveDatingPresets(from: $0, to: $1) }
                } header: {
                    sectionHeader("Dating", enabled: vm.datingPresets.filter(\.isEnabled).count)
                } footer: {
                    Text("Only shown in the keyboard's Dating mode.")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                Section {
                    ForEach(vm.emailPresets) { tone in
                        PresetToneRow(tone: tone, onToggle: { vm.toggle(tone) })
                            .listRowBackground(ReplrTheme.Color.surface)
                            .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                    }
                    .onMove { vm.moveEmailPresets(from: $0, to: $1) }
                } header: {
                    sectionHeader("Email", enabled: vm.emailPresets.filter(\.isEnabled).count)
                } footer: {
                    Text("Only shown in the keyboard's Email mode — the professional register.")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                if !vm.custom.isEmpty {
                    Section {
                        ForEach(vm.custom) { tone in
                            PresetToneRow(tone: tone, onToggle: { vm.toggle(tone) },
                                          modeTags: sharedTags(for: tone))
                                .listRowBackground(ReplrTheme.Color.surface)
                                .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                        }
                        .onDelete { vm.delete(at: $0) }
                    } header: {
                        Text("Custom")
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    } footer: {
                        Text("Your tones appear in the modes you picked when creating them. Swipe to delete.")
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .brandScreenBackground()
            .tint(ReplrTheme.Color.accent)
            .navigationTitle("Tones")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Button { showBuilder = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showBuilder) {
                ToneBuilderView(onSave: { vm.add($0); showBuilder = false })
            }
            .onAppear { vm.load() }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, enabled: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(ReplrTheme.Color.textSecondary)
            Spacer()
            Text("\(enabled) on keyboard")
                .font(.caption)
                .foregroundStyle(ReplrTheme.Color.accent)
        }
    }

    /// Mode tags shown on a row. Chat presets that ALSO appear in Dating/Email get
    /// tagged (their home section is Chat); custom tones always show their picked
    /// modes so it's clear where each one lives.
    private func sharedTags(for tone: Tone) -> [String] {
        guard tone.isPreset else {
            let order = ["chat": 0, "dating": 1, "email": 2]
            return tone.modes.sorted { (order[$0] ?? 9) < (order[$1] ?? 9) }.map(\.capitalized)
        }
        guard Tone.chatToneNames.contains(tone.name) else { return [] }
        var tags: [String] = []
        if Tone.datingToneNames.contains(tone.name) { tags.append("Dating") }
        if Tone.emailToneNames.contains(tone.name) { tags.append("Email") }
        return tags
    }
}

struct PresetToneRow: View {
    let tone: Tone
    let onToggle: () -> Void
    /// Extra modes this tone appears in (capsule tags after the name).
    var modeTags: [String] = []
    /// Natural: the always-on baseline — no toggle, can't be disabled.
    var lockedOn: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ReplrTheme.Color.accent.opacity(tone.isEnabled ? 0.85 : 0.2))
                .frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                // Name owns its line — tags live below, so it can never squeeze
                // into a hyphenated wrap no matter how many tags a tone carries.
                Text(tone.name)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)
                if lockedOn || showsDefaultTag || !modeTags.isEmpty {
                    HStack(spacing: 4) {
                        if lockedOn {
                            tagCapsule("Always on", prominent: true)
                        } else if showsDefaultTag {
                            tagCapsule("default", prominent: true)
                        }
                        ForEach(modeTags, id: \.self) { tagCapsule($0, prominent: false) }
                    }
                }
                Text(tone.blurb.isEmpty ? tone.instruction : tone.blurb)
                    .font(.caption)
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if !lockedOn {
                Toggle("", isOn: Binding(get: { tone.isEnabled }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .tint(ReplrTheme.Color.accent)
            }
        }
        .padding(.vertical, 2)
    }

    private var showsDefaultTag: Bool {
        // Natural = chat/email default; Tease = dating default (ModeSegmentedControl fallback).
        tone.isPreset && tone.isEnabled && (tone.name == "Natural" || tone.name == "Tease")
    }

    private func tagCapsule(_ label: String, prominent: Bool) -> some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(prominent ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(prominent ? ReplrTheme.Color.accentSubtle : ReplrTheme.Color.surfaceRaised)
            .clipShape(Capsule())
    }
}
