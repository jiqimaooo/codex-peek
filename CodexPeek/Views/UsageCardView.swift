import SwiftUI

struct UsageCardView: View {
    let window: UsageWindow
    let language: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(Int(window.usedPercent.rounded()))%")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                ProgressBarView(progress: window.normalizedProgress, status: window.status)

                VStack(spacing: 8) {
                    detailRow(title: L(.usedTotal, language), value: window.totalDescription)
                    detailRow(title: L(.remaining, language), value: "\(window.remainingPercent.cleanUsageString)%")
                    detailRow(title: L(.reset, language), value: resetText)
                }
            }
        }
        .groupBoxStyle(.automatic)
    }

    private var title: String {
        switch window.kind {
        case .fiveHours:
            return L(.fiveHourUsage, language)
        case .weekly:
            return L(.weeklyUsage, language)
        }
    }

    private var resetText: String {
        guard let resetsAt = window.resetsAt else { return L(.unknown, language) }
        return DateFormatter.usageTimestamp.string(from: resetsAt)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 12))
    }
}
