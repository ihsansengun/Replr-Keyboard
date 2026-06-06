import SwiftUI

// Hand-drawn amber annotations for onboarding coachmarks (Wispr-style).
// Decorative only — no interaction. Default tint is the brand amber.

/// An open, slightly tilted ellipse stroke that reads as a hand-drawn circle.
struct DoodleCircle: View {
    var color: Color = ReplrTheme.Color.amber
    var lineWidth: CGFloat = 3

    var body: some View {
        Ellipse()
            .trim(from: 0.04, to: 0.97)            // leave a gap so it reads hand-drawn
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-12))
    }
}

/// A curved arrow that bows down-left and ends in a small arrowhead.
struct DoodleArrow: View {
    var color: Color = ReplrTheme.Color.amber
    var lineWidth: CGFloat = 3

    var body: some View {
        DoodleArrowShape()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

private struct DoodleArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let start = CGPoint(x: rect.minX + rect.width * 0.05, y: rect.minY + rect.height * 0.10)
        let end   = CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.height * 0.12)
        let control = CGPoint(x: rect.minX, y: rect.maxY)        // bow the curve down-left
        p.move(to: start)
        p.addQuadCurve(to: end, control: control)
        // Arrowhead: two short strokes off the end point.
        let h = min(rect.width, rect.height) * 0.18
        p.move(to: CGPoint(x: end.x - h, y: end.y - h * 0.35))
        p.addLine(to: end)
        p.addLine(to: CGPoint(x: end.x - h * 0.35, y: end.y - h))
        return p
    }
}

#Preview("Doodles — light") {
    VStack(spacing: 44) {
        DoodleCircle().frame(width: 130, height: 72)
        DoodleArrow().frame(width: 90, height: 90)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ReplrTheme.Color.bg)
}

#Preview("Doodles — dark") {
    VStack(spacing: 44) {
        DoodleCircle().frame(width: 130, height: 72)
        DoodleArrow().frame(width: 90, height: 90)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ReplrTheme.Color.bg)
    .preferredColorScheme(.dark)
}
