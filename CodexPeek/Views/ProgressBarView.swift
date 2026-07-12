import SwiftUI

struct ProgressBarView: View {
    let progress: Double
    let status: LimitStatus
    let alignment: Alignment

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: alignment) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(8, proxy.size.width * progress))
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Usage progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }

    private var fillColor: Color {
        switch status {
        case .normal:
            return .primary.opacity(0.72)
        case .nearLimit:
            return .orange
        case .limited:
            return AppColors.quotaRed
        }
    }
}
