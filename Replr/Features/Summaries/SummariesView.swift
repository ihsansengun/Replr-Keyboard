import SwiftUI

final class SummariesViewModel: ObservableObject {
    @Published var summaries: [ConversationSummary] = []

    private let key = "summaries"
    private let defaults = UserDefaults(suiteName: Constants.appGroupID)

    func load() {
        guard
            let data = defaults?.data(forKey: key),
            let decoded = try? JSONDecoder().decode([ConversationSummary].self, from: data)
        else { return }
        summaries = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(summaries) else { return }
        defaults?.set(data, forKey: key)
    }

    func add(_ summary: ConversationSummary) {
        summaries.append(summary)
        save()
    }

    func update(_ summary: ConversationSummary) {
        if let idx = summaries.firstIndex(where: { $0.id == summary.id }) {
            summaries[idx] = summary
            save()
        }
    }

    func delete(at offsets: IndexSet) {
        summaries.remove(atOffsets: offsets)
        save()
    }
}

struct SummariesView: View {
    @StateObject private var vm = SummariesViewModel()
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.summaries) { summary in
                    NavigationLink(destination: SummaryDetailView(summary: summary, onSave: vm.update)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.personName).font(.headline)
                            Text(summary.platform).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: vm.delete)
            }
            .navigationTitle("Summaries")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showingAdd) {
                AddSummaryView(onAdd: { vm.add($0); showingAdd = false })
            }
            .onAppear { vm.load() }
        }
    }
}

struct AddSummaryView: View {
    var onAdd: (ConversationSummary) -> Void
    @State private var name = ""
    @State private var platform = "iMessage"
    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss

    let platforms = ["iMessage", "WhatsApp", "Tinder", "Hinge", "Gmail", "Instagram"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Platform", selection: $platform) {
                    ForEach(platforms, id: \.self) { Text($0) }
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
            }
            .navigationTitle("New Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(ConversationSummary(id: UUID(), personName: name, platform: platform, notes: notes, updatedAt: .now))
                    }.disabled(name.isEmpty)
                }
            }
        }
    }
}
