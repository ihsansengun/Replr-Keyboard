import SwiftUI
import Combine

final class TonesViewModel: ObservableObject {
    @Published var tones: [Tone] = []

    func load() { tones = AppGroupService.shared.readTones() }

    func save() { try? AppGroupService.shared.writeTones(tones) }

    func add(_ tone: Tone) { tones.append(tone); save() }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { tones[$0] }.filter { !$0.isPreset }
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
                Section("Presets") {
                    ForEach(vm.tones.filter(\.isPreset)) { tone in
                        ToneRow(tone: tone)
                    }
                }
                Section("Custom") {
                    ForEach(vm.tones.filter { !$0.isPreset }) { tone in
                        ToneRow(tone: tone)
                    }
                    .onDelete { vm.delete(at: $0) }
                }
                let hasDating = vm.tones.filter { !$0.isPreset }.contains { $0.name.lowercased() == "dating" }
                if !hasDating {
                    Section("Suggested") {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Dating")
                                    .font(.body)
                                Text("Confident and genuine. Light wit when it fits. Never desperate, never try-hard.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(2)
                            }
                            Spacer()
                            Button("Add") {
                                let dating = Tone(
                                    id: UUID(),
                                    name: "Dating",
                                    instruction: "Confident and genuine. Light wit when it fits. Never desperate, never try-hard.",
                                    isPreset: false
                                )
                                vm.add(dating)
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ReplrTheme.Color.accent)
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Tones")
            .toolbar {
                Button { showBuilder = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showBuilder) {
                ToneBuilderView(onSave: { vm.add($0); showBuilder = false })
            }
            .onAppear { vm.load() }
        }
    }
}

struct ToneRow: View {
    let tone: Tone
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ReplrTheme.Color.accent.opacity(tone.isPreset ? 0.85 : 0.35))
                .frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(tone.name).font(.headline)
                Text(tone.instruction).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
