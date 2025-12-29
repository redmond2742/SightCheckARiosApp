import SwiftUI

struct SightTriangleOverlayView: View {
    let match: SightTargetMatch

    private var triangleColor: Color {
        match.target.isClear ? Color.green : Color.red
    }

    private var alignmentOpacity: Double {
        match.isAligned ? 0.95 : 0.5
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                TriangleShape()
                    .fill(triangleColor)
                    .frame(width: 150, height: 120)
                    .overlay(
                        TriangleShape()
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    )
                    .rotationEffect(.degrees(match.signedHeadingDelta))
                    .shadow(color: triangleColor.opacity(0.6), radius: 12)

                VStack(spacing: 2) {
                    Text("Location \(match.target.locationNumber)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Bearing \(Int(match.target.compassBearing))° • Δ\(Int(match.headingDelta))°")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))

                    Text("\(Int(match.distance))m away")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.6))
                )
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(alignmentOpacity)
        .animation(.easeInOut(duration: 0.2), value: match.isAligned)
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
