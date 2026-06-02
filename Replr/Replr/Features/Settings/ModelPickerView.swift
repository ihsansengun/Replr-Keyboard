import SwiftUI

/// Developer-only view. Not accessible from normal navigation.
/// Reached via long-press on version label in SettingsView.
struct ModelPickerView: View {
    @State private var selectedModelID = AppGroupService.shared.devMode
        ? AppGroupService.shared.devModel
        : AppGroupService.shared.userModel
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
                Text("Gives you unlimited credits for testing. Model switching works for all users via Settings → AI Model. Use this to try experimental models not yet in the main UI.")
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
                        // In dev mode, override the dev model; user's production choice stays untouched
                        if AppGroupService.shared.devMode {
                            AppGroupService.shared.devModel = model.apiModelID
                        } else {
                            AppGroupService.shared.userModel = model.apiModelID
                        }
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
            devMode = AppGroupService.shared.devMode
            selectedModelID = devMode
                ? AppGroupService.shared.devModel
                : AppGroupService.shared.userModel
        }
    }
}
