import SwiftUI

// MARK: - Disambiguate Panel

struct DisambiguatePanelView: View {
    @ObservedObject var model: KeyboardModel
    let name: String
    let candidates: [Contact]

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, isSegmentedDisabled: true, isToneHidden: true)
            DisambiguateView(
                name: name,
                candidates: candidates,
                onSelectContact: { model.onSelectContact?($0) },
                onCreateNew: { model.onCreateNewContact?($0) }
            )
        }
        .background(ReplrTheme.Color.bg)
    }
}

// MARK: - Disambiguate View (contact picker list)

struct DisambiguateView: View {
    let name: String
    let candidates: [Contact]
    var onSelectContact: ((Contact) -> Void)?
    var onCreateNew: ((String) -> Void)?

    private let thumbnails: [UUID: UIImage]

    init(name: String, candidates: [Contact],
         onSelectContact: ((Contact) -> Void)? = nil,
         onCreateNew: ((String) -> Void)? = nil) {
        self.name = name
        self.candidates = candidates
        self.onSelectContact = onSelectContact
        self.onCreateNew = onCreateNew
        var map: [UUID: UIImage] = [:]
        for contact in candidates {
            if let data = AppGroupService.shared.sessions(forContactID: contact.id)
                    .last?.thumbnailData,
               let img = UIImage(data: data) {
                map[contact.id] = img
            }
        }
        self.thumbnails = map
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Which \(name)?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ReplrTheme.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ReplrTheme.Color.bg)

            ReplrTheme.Color.border.frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(candidates) { contact in
                        Button { onSelectContact?(contact) } label: {
                            HStack(spacing: 10) {
                                thumbnailView(for: contact)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.displayName)
                                        .font(.system(size: 13))
                                        .foregroundColor(ReplrTheme.Color.textPrimary)
                                    if let summary = AppGroupService.shared
                                            .recentSummaries(forContactID: contact.id, limit: 1).first {
                                        Text(summary)
                                            .font(.system(size: 11))
                                            .foregroundColor(ReplrTheme.Color.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .background(ReplrTheme.Color.surface)
                        .overlay(alignment: .bottom) {
                            ReplrTheme.Color.border.frame(height: 0.5)
                        }
                    }

                    Button { onCreateNew?(name) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                            Text("New contact named \(name)")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(ReplrTheme.Color.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(ReplrTheme.Color.bg)
    }

    @ViewBuilder
    private func thumbnailView(for contact: Contact) -> some View {
        if let img = thumbnails[contact.id] {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(ReplrTheme.Color.surface)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: 12))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                )
        }
    }
}
