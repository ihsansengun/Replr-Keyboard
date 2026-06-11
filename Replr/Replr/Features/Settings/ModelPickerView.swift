import SwiftUI
import Photos  // SPIKE — remove after Phase 0

/// Developer-only view. Not accessible from normal navigation.
/// Reached via long-press on version label in SettingsView.
struct ModelPickerView: View {
    @State private var selectedModelID = AppGroupService.shared.devMode
        ? AppGroupService.shared.devModel
        : AppGroupService.shared.userModel
    @State private var devMode = AppGroupService.shared.devMode
    @ObservedObject private var credits = CreditsManager.shared
    struct ModelCostStat: Identifiable {
        let id: String        // model identifier
        let cost: Double
        let inputTokens: Int
        let outputTokens: Int
        let captures: Int
    }

    @State private var photosStatus: String = "\(PHPhotoLibrary.authorizationStatus(for: .readWrite).rawValue)"  // SPIKE — remove after Phase 0
    @State private var totalCostUsd: Double = 0
    @State private var modelStats: [ModelCostStat] = []
    @State private var testResults: [String: ModelTestResult] = [:]
    @State private var testing = false

    private func refreshCostStats() {
        let sessions = AppGroupService.shared.loadCaptureSessions()
        totalCostUsd = sessions.compactMap(\.costUsd).reduce(0, +)

        // Group by model
        var grouped: [String: (cost: Double, input: Int, output: Int, count: Int)] = [:]
        for s in sessions {
            guard let model = s.modelUsed, let cost = s.costUsd else { continue }
            let cur = grouped[model] ?? (0, 0, 0, 0)
            grouped[model] = (
                cur.cost + cost,
                cur.input + (s.inputTokens ?? 0),
                cur.output + (s.outputTokens ?? 0),
                cur.count + 1
            )
        }
        modelStats = grouped
            .map { ModelCostStat(id: $0.key, cost: $0.value.cost, inputTokens: $0.value.input, outputTokens: $0.value.output, captures: $0.value.count) }
            .sorted { $0.cost > $1.cost }
    }

    /// Ping every model on the backend (sequentially, to be gentle on rate limits) and record
    /// OK + latency or the raw error — so failures are visible right here on the model screen.
    private func testAllModels() {
        testing = true
        testResults = [:]
        Task {
            for model in ReplrModel.allCases {
                let result = await ReplyService.shared.testModel(model.apiModelID)
                await MainActor.run { testResults[model.apiModelID] = result }
            }
            await MainActor.run { testing = false }
        }
    }

    var body: some View {
        List {
            // MARK: Dev Mode
            Section {
                Toggle("Dev Mode (∞ credits, no deduction)", isOn: $devMode)
                    .tint(ReplrTheme.Color.accent)
                    .onChange(of: devMode) { value in
                        AppGroupService.shared.devMode = value
                        credits.refreshBalance()
                        // When toggling, update display to correct model
                        selectedModelID = value
                            ? AppGroupService.shared.devModel
                            : AppGroupService.shared.userModel
                    }
            } header: {
                Text("Testing")
            } footer: {
                Text("Unlimited credits for testing. Model selection here overrides the user-facing setting while dev mode is on.")
                    .font(.caption)
            }

            // MARK: Model Comparison Table
            Section {
                Button {
                    testAllModels()
                } label: {
                    HStack(spacing: 8) {
                        if testing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "stethoscope")
                        }
                        Text(testing ? "Testing all models…" : "Test all models")
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(ReplrTheme.Color.accent)
                }
                .disabled(testing)

                ForEach(ReplrModel.allCases) { model in
                    ModelRow(
                        model: model,
                        isSelected: selectedModelID == model.apiModelID,
                        testResult: testResults[model.apiModelID],
                        onTap: {
                            selectedModelID = model.apiModelID
                            if AppGroupService.shared.devMode {
                                AppGroupService.shared.devModel = model.apiModelID
                            } else {
                                AppGroupService.shared.userModel = model.apiModelID
                            }
                        }
                    )
                }
            } header: {
                HStack {
                    Text("Model")
                    Spacer()
                    Text("Elo")
                        .frame(width: 46, alignment: .trailing)
                    Text("$/req")
                        .frame(width: 52, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ReplrTheme.Color.textTertiary)
            } footer: {
                Text("★ = top-3 Arena Elo. Production users see only the Balanced/Max tiers; the backend maps tiers to vendor models (services/models.ts TIERS).")
                    .font(.caption)
            }

            // MARK: Balance
            Section("Current Balance") {
                HStack {
                    Text("Credits")
                    Spacer()
                    Text(credits.balanceDisplay)
                        .foregroundStyle(ReplrTheme.Color.accent)
                        .fontWeight(.semibold)
                }
            }

            // SPIKE — remove after Phase 0
            Section {
                Button("Request Photos Access") {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        DispatchQueue.main.async { photosStatus = "\(status.rawValue)" }
                    }
                }
                HStack {
                    Text("Auth status (raw)")
                    Spacer()
                    Text(photosStatus).foregroundStyle(ReplrTheme.Color.textSecondary)
                }
            } header: {
                Text("Photos Permission (spike)")
            } footer: {
                Text("raw values: 0=notDetermined 1=restricted 2=denied 3=authorized 4=limited")
                    .font(.caption)
            }

            // MARK: Total API Cost
            Section {
                // Total row
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "$%.4f", totalCostUsd))
                        .foregroundStyle(ReplrTheme.Color.accent)
                        .fontWeight(.semibold)
                        .font(.system(size: 15).monospacedDigit())
                }

                // Per-model breakdown
                ForEach(modelStats) { stat in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stat.id)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ReplrTheme.Color.textPrimary)
                            Spacer()
                            Text(String(format: "$%.4f", stat.cost))
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(ReplrTheme.Color.textPrimary)
                        }
                        HStack(spacing: 12) {
                            Text("\(stat.captures) capture\(stat.captures == 1 ? "" : "s")")
                            Text("↓ \(stat.inputTokens) in")
                            Text("↑ \(stat.outputTokens) out")
                        }
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                    }
                    .padding(.vertical, 2)
                }

                if modelStats.isEmpty {
                    Text("No cost data yet. Make a capture first.")
                        .font(.system(size: 13))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                }
            } header: {
                Text("Total API Cost")
            } footer: {
                Text("Cumulative cost per model. Only captures made after cost tracking was deployed are included.")
                    .font(.caption)
            }
        }
        .navigationTitle("Dev: Model Picker")
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .onAppear {
            devMode = AppGroupService.shared.devMode
            selectedModelID = devMode
                ? AppGroupService.shared.devModel
                : AppGroupService.shared.userModel
            refreshCostStats()
        }
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: ReplrModel
    let isSelected: Bool
    var testResult: ModelTestResult? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary)

                // Name + tier badge
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(model.displayName)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(ReplrTheme.Color.textPrimary)
                        if !model.isProductionModel {
                            Text("DEV")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(ReplrTheme.Color.textTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(ReplrTheme.Color.surfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    Text("\(model.creditsPerRequest) credit\(model.creditsPerRequest == 1 ? "" : "s") / reply")
                        .font(.system(size: 11))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)

                    if let r = testResult {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: r.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text(r.ok ? "OK · \(r.latencyMs)ms" : r.message)
                                .font(.system(size: 10))
                                .lineLimit(r.ok ? 1 : 6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(r.ok ? Color.green : Color.red)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Arena Elo
                Text(model.arenaElo)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(model.eloColor)
                    .frame(width: 46, alignment: .trailing)

                // Cost per request
                Text(model.costPerRequest)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(model.costColor)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(ReplrTheme.Motion.quick, value: isSelected)
    }
}
