import SwiftUI

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel
    @State private var ring1 = false
    @State private var ring2 = false

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            captureZone
                .padding(10)
            Spacer(minLength: 0)
        }
    }

    private var captureZone: some View {
        VStack(spacing: 10) {
            ZStack {
                Image(systemName: "iphone.rear.camera")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(KBColors.accent)

                // Two staggered ripple rings emanating from the phone back
                Circle()
                    .stroke(KBColors.accent, lineWidth: 1.5)
                    .frame(width: ring1 ? 44 : 6, height: ring1 ? 44 : 6)
                    .opacity(ring1 ? 0 : 0.75)
                    .offset(y: -2)

                Circle()
                    .stroke(KBColors.accent, lineWidth: 1.5)
                    .frame(width: ring2 ? 44 : 6, height: ring2 ? 44 : 6)
                    .opacity(ring2 ? 0 : 0.75)
                    .offset(y: -2)
            }
            .frame(height: 48)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    ring1 = true
                }
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false).delay(0.55)) {
                    ring2 = true
                }
            }

            Text("Back Tap to capture")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KBColors.accent)
            Text("screenshot → AI replies")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
