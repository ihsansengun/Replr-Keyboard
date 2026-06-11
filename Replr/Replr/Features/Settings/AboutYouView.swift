import SwiftUI

/// Free-text "About you" editor — opened from Settings and the Home tile.
struct AboutYouView: View {
    @State private var aboutUser = AppGroupService.shared.aboutUser
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: "About You") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(
                            "Age, gender, your vibe, what you're into…",
                            text: $aboutUser,
                            axis: .vertical
                        )
                        .font(.system(size: 15))
                        .lineLimit(3...6)
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                        .focused($focused)
                        .onChange(of: aboutUser) { newValue in
                            let capped = newValue.count > 300 ? String(newValue.prefix(300)) : newValue
                            if newValue.count > 300 { aboutUser = capped }
                            AppGroupService.shared.aboutUser = capped
                        }
                        Text("e.g. 27, guy, dry sense of humour, into climbing and techno")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textTertiary)
                            .padding(.top, 2)
                        Text("Stays on your device. Sent only to draft your replies.")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("About you")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.accent)
            }
        }
        .onAppear { aboutUser = AppGroupService.shared.aboutUser }
    }
}
