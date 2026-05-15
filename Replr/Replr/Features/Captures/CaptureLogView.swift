import SwiftUI

final class CaptureLogViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []

    func load() {
        sessions = AppGroupService.shared.loadCaptureSessions().reversed()
    }

    func clearAll() {
        AppGroupService.shared.clearCaptureSessions()
        sessions = []
    }

    func delete(at offsets: IndexSet) {
        // offsets are into the reversed array; map back, remove, re-save
        var all = AppGroupService.shared.loadCaptureSessions()
        let totalCount = all.count
        let allOffsets = IndexSet(offsets.map { totalCount - 1 - $0 })
        all.remove(atOffsets: allOffsets)
        AppGroupService.shared.saveCaptureSessions(all)
        sessions.remove(atOffsets: offsets)
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
                    List {
                        ForEach(vm.sessions) { session in
                            NavigationLink(destination: CaptureDetailView(session: session)) {
                                CaptureRowView(session: session)
                            }
                        }
                        .onDelete(perform: vm.delete)
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
}

struct CaptureRowView: View {
    let session: CaptureSession

    var body: some View {
        HStack(spacing: 12) {
            if let data = session.thumbnailData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 36, height: 64)
                    .overlay(Image(systemName: "text.bubble").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let summary = session.llmSummary {
                    Text(summary)
                        .font(.subheadline)
                        .lineLimit(2)
                }

                if let selected = session.selectedReply {
                    Text("Sent: \(selected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CaptureDetailView: View {
    let session: CaptureSession

    var body: some View {
        List {
            Section("Screenshot") {
                if let data = session.thumbnailData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("No screenshot (email capture)")
                        .foregroundStyle(.secondary)
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
                    HStack {
                        Text(reply)
                        if reply == session.selectedReply {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.timestamp, style: .date)
        .navigationBarTitleDisplayMode(.inline)
    }
}
