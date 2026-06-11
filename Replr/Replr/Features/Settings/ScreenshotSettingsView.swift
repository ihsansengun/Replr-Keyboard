import SwiftUI
import Photos

/// Deletes ONLY the screenshots Replr recorded (by localIdentifier). Never touches other photos.
enum ScreenshotCleaner {
    static func pendingCount() -> Int {
        AppGroupService.shared.capturedScreenshotIDs().count
    }

    /// Batch-deletes recorded screenshots. iOS shows one confirmation. Clears the list on success.
    static func clean(completion: ((Bool) -> Void)? = nil) {
        let ids = AppGroupService.shared.capturedScreenshotIDs()
        guard !ids.isEmpty else { completion?(true); return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assets.count > 0 else {
            AppGroupService.shared.clearCapturedScreenshotIDs()   // all already gone
            completion?(true); return
        }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        } completionHandler: { success, _ in
            DispatchQueue.main.async {
                if success { AppGroupService.shared.clearCapturedScreenshotIDs() }
                completion?(success)
            }
        }
    }
}

/// Settings → Screenshots: cleanup toggles + the wordy explainers, off the root.
struct ScreenshotSettingsView: View {
    @State private var autoClear = AppGroupService.shared.autoClearScreenshots
    @State private var deleteAfterEach = AppGroupService.shared.deleteScreenshotAfterEach
    @State private var pendingShots = ScreenshotCleaner.pendingCount()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: "Cleanup") {
                    SettingsRow {
                        Text("Auto-clear captured screenshots").font(.system(size: 17))
                        Spacer()
                        BrandToggle(isOn: $autoClear)
                            .onChange(of: autoClear) { AppGroupService.shared.autoClearScreenshots = $0 }
                    }
                    if autoClear {
                        CardDivider()
                        SettingsRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete after each reply").font(.system(size: 17))
                                Text(deleteAfterEach ? "Each one, as soon as you reopen Replr" : "In batches, once a few pile up")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                            }
                            Spacer()
                            BrandToggle(isOn: $deleteAfterEach)
                                .onChange(of: deleteAfterEach) { AppGroupService.shared.deleteScreenshotAfterEach = $0 }
                        }
                    }
                    if pendingShots > 0 {
                        CardDivider()
                        Button {
                            ScreenshotCleaner.clean { _ in pendingShots = ScreenshotCleaner.pendingCount() }
                        } label: {
                            SettingsRow {
                                Text("Clear \(pendingShots) captured screenshot\(pendingShots == 1 ? "" : "s")")
                                    .font(.system(size: 17))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(ReplrTheme.Motion.quick, value: autoClear)
                .animation(ReplrTheme.Motion.quick, value: pendingShots)

                Text("Only deletes screenshots Replr captured for replies, never your other photos. Cleanup runs the next time you open Replr (iOS can't let the keyboard delete photos on its own), and iOS asks you to confirm.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 4)

                if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Faster capture on iOS 26")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.textPrimary)
                        Text("Screenshots open a full editor instead of saving on their own. For one-tap capture, open the Settings app → Screen Capture and turn off Full-Screen Previews. Optional: capture still works, you'll just tap Save first.")
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                }
                Spacer(minLength: 110)
            }
            .padding(20)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { pendingShots = ScreenshotCleaner.pendingCount() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { pendingShots = ScreenshotCleaner.pendingCount() }
        }
    }
}
