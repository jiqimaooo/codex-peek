import SwiftUI

struct CodexMarkIcon: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.16, to: 0.79)
                .stroke(
                    Color.primary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(34))

            Circle()
                .trim(from: 0.86, to: 0.98)
                .stroke(
                    Color.secondary.opacity(0.72),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(34))

            Circle()
                .trim(from: 0.02, to: 0.08)
                .stroke(
                    Color.secondary.opacity(0.56),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(34))

            Text("C")
                .font(.system(size: size * 0.56, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
        .drawingGroup()
        .accessibilityHidden(true)
    }

    private var lineWidth: CGFloat {
        max(1.8, size * 0.15)
    }
}
