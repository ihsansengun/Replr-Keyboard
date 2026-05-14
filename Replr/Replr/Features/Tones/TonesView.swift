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
        VStack(alignment: .leading, spacing: 2) {
            Text(tone.name).font(.headline)
            Text(tone.instruction).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
    }
}
