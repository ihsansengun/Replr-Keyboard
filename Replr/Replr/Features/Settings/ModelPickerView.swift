import SwiftUI

/// Developer-only view. Not accessible from normal navigation.
/// Reached via long-press on version label in SettingsView.
struct ModelPickerView: View {
    @State private var selectedModelID = AppGroupService.shared.selectedModel
    @State private var devMode = AppGroupService.shared.devMode
    @ObservedObject private var credits = CreditsManager.shared

    var body: some View {
        List {
            Section {
                Toggle("Dev Mode (∞ credits, no deduction)", isOn: $devMode)
                    .tint(ReplrTheme.Color.accent)
                    .onChange(of: devMode) { value in
                        AppGroupService.shared.devMode = value
                        credits.refreshBalance()
                    }
            } header: {
                Text("Testing")
            } footer: {
                Text("When on: balance shows ∞, credits are never deducted. Off by default for all users.")
                    .font(.caption)
            }

            Section("Model") {
                ForEach(ReplrModel.allCases) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(.system(size: 15))
                                .foregroundStyle(ReplrTheme.Color.textPrimary)
                            Text("\(model.creditsPerRequest) credit\(model.creditsPerRequest == 1 ? "" : "s") / reply · \(model.apiModelID)")
                                .font(.system(size: 11))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        Spacer()
                        if selectedModelID == model.apiModelID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(ReplrTheme.Color.accent)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedModelID = model.apiModelID
                        AppGroupService.shared.selectedModel = model.apiModelID
                    }
                }
            }

            Section("Current Balance") {
                HStack {
                    Text("Credits")
                    Spacer()
                    Text(credits.balanceDisplay)
                        .foregroundStyle(ReplrTheme.Color.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle("Dev: Model Picker")
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .onAppear {
            selectedModelID = AppGroupService.shared.selectedModel
            devMode = AppGroupService.shared.devMode
        }
    }
}
