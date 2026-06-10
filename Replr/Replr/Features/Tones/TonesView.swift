import SwiftUI
import Combine

final class TonesViewModel: ObservableObject {
    @Published var tones: [Tone] = []

    var presets: [Tone] { tones.filter(\.isPreset) }
    var custom: [Tone]  { tones.filter { !$0.isPreset } }
    var enabledCount: Int { tones.filter(\.isEnabled).count }

    /// Chat/email presets — everything except the dating-only set.
    var generalPresets: [Tone] { tones.filter { $0.isPreset && !Tone.datingOnlyToneNames.contains($0.name) } }
    /// Dating-only presets (the Settings "Dating" section).
    var datingPresets: [Tone]  { tones.filter { $0.isPreset && Tone.datingOnlyToneNames.contains($0.name) } }

    func load() { tones = AppGroupService.shared.readTones() }

    func save() { try? AppGroupService.shared.writeTones(tones) }

    func toggle(_ tone: Tone) {
        guard let idx = tones.firstIndex(where: { $0.id == tone.id }) else { return }
        tones[idx].isEnabled.toggle()
        save()
    }

    func add(_ tone: Tone) { tones.append(tone); save() }

    /// Reorder presets within a section (drag-to-reorder in Settings). Order persists
    /// and drives the keyboard row order. Storage layout: general presets, then
    /// dating presets, then custom tones.
    private func stitch(general: [Tone], dating: [Tone]) {
        tones = general + dating + custom
        save()
    }

    func moveGeneralPresets(from source: IndexSet, to destination: Int) {
        var g = generalPresets
        g.move(fromOffsets: source, toOffset: destination)
        stitch(general: g, dating: datingPresets)
    }

    func moveDatingPresets(from source: IndexSet, to destination: Int) {
        var d = datingPresets
        d.move(fromOffsets: source, toOffset: destination)
        stitch(general: generalPresets, dating: d)
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
                    ForEach(vm.generalPresets) { tone in
                        PresetToneRow(tone: tone, onToggle: { vm.toggle(tone) }, showDragHandle: true)
                            .listRowBackground(ReplrTheme.Color.surface)
                            .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                    }
                    .onMove { vm.moveGeneralPresets(from: $0, to: $1) }
                } header: {
                    HStack {
                        Text("Presets")
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                        Spacer()
                        Text("\(vm.enabledCount) on keyboard")
                            .font(.caption)
                            .foregroundStyle(ReplrTheme.Color.accent)
                    }
                } footer: {
                    Text("Tap the toggle to add or remove a tone from your keyboard. Drag the ≡ handle to reorder.")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                Section {
                    ForEach(vm.datingPresets) { tone in
                        PresetToneRow(tone: tone, onToggle: { vm.toggle(tone) }, showDragHandle: true)
                            .listRowBackground(ReplrTheme.Color.surface)
                            .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                    }
                    .onMove { vm.moveDatingPresets(from: $0, to: $1) }
                } header: {
                    Text("Dating")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                } footer: {
                    Text("Only shown in the keyboard's Dating mode.")
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                if !vm.custom.isEmpty {
                    Section {
                        ForEach(vm.custom) { tone in
                            PresetToneRow(tone: tone, onToggle: { vm.toggle(tone) })
                                .listRowBackground(ReplrTheme.Color.surface)
                                .listRowSeparatorTint(ReplrTheme.Color.glassBorder)
                        }
                        .onDelete { vm.delete(at: $0) }
                    } header: {
                        Text("Custom")
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
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
}

struct PresetToneRow: View {
    let tone: Tone
    let onToggle: () -> Void
    var showDragHandle: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ReplrTheme.Color.accent.opacity(tone.isEnabled ? 0.85 : 0.2))
                .frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tone.name).font(.headline)
                    if tone.isPreset && tone.isEnabled && isDefaultPreset(tone) {
                        Text("default")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ReplrTheme.Color.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ReplrTheme.Color.accentSubtle)
                            .clipShape(Capsule())
                    }
                }
                Text(tone.blurb.isEmpty ? tone.instruction : tone.blurb)
                    .font(.caption)
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { tone.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .tint(ReplrTheme.Color.accent)
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ReplrTheme.Color.textTertiary)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 2)
    }

    private func isDefaultPreset(_ tone: Tone) -> Bool {
        // Natural = chat/email default; Tease = dating default (ModeSegmentedControl fallback).
        tone.name == "Natural" || tone.name == "Tease"
    }
}
