import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What happens when you capture a chat")
                        .font(.headline)
                    Text("When you trigger a capture, the screenshot is sent from your device to Replr's server. The server calls an AI provider (Claude or GPT-4o) to write the replies. The screenshot is not stored on any server after the replies are returned.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What stays on your device")
                        .font(.headline)
                    Text("After each capture, a one-line summary of the conversation is saved on your device — in the app's private storage — for the memory feature. This summary is never sent to any server. It is only used as context for future replies with the same contact.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    Text("You can view and delete every summary Replr holds in the Memory tab.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your photo library")
                        .font(.headline)
                    Text("Replr's primary capture method (Back Tap → Shortcut) never accesses your photo library. The screenshot is passed directly to Replr in memory and is never saved to Photos.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Full Access")
                        .font(.headline)
                    Text("Replr requires Full Access for the keyboard extension. This lets the keyboard communicate with the companion app through a private shared storage area on your device. It does not grant access to anything you type in other apps.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
