import SwiftUI

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            VStack(spacing: 8) {
                captureZone
                if model.hasAnySessions, model.contactName != nil || lastSummary != nil {
                    lastCaptureCard
                }
            }
            .padding(10)
            Spacer(minLength: 0)
        }
    }

    private var captureZone: some View {
        VStack(spacing: 6) {
            Text("✦")
                .font(.system(size: 20))
                .foregroundColor(KBColors.accent)
            Text("Back Tap to capture")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KBColors.accent)
            Text("screenshot → AI replies")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    KBColors.accent.opacity(0.33),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
        )
    }

    private var lastCaptureCard: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(KBColors.surface)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(model.contactName.map { String($0.prefix(1)).uppercased() } ?? "?")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(KBColors.accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                if let name = model.contactName {
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(KBColors.textPrimary)
                }
                if let summary = lastSummary {
                    Text(summary)
                        .font(.system(size: 10))
                        .foregroundColor(KBColors.textDim)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KBColors.borderHair, lineWidth: 0.5)
        )
    }

    private var lastSummary: String? {
        guard let id = AppGroupService.shared.currentContactID else { return nil }
        return AppGroupService.shared.recentSummaries(forContactID: id, limit: 1).first
    }
}
