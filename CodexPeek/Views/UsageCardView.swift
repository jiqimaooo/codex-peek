import SwiftUI

struct UsageCardView: View {
    let window: UsageWindow
    let language: String
    @AppStorage("displayMode") private var displayMode = DisplayMode.usage.rawValue

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(displayPercent)%")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                ProgressBarView(
                    progress: displayProgress,
                    status: window.status,
                    alignment: displayMode == DisplayMode.remaining.rawValue ? .trailing : .leading
                )

                VStack(spacing: 8) {
                    detailRow(title: L(.usedTotal, language), value: window.totalDescription)
                    detailRow(title: L(.remaining, language), value: "\(window.remainingPercent.cleanUsageString)%")
                    detailRow(title: L(.reset, language), value: resetText)
                }
            }
        }
        .groupBoxStyle(.automatic)
    }

    private var displayPercent: Int {
        if displayMode == DisplayMode.remaining.rawValue {
            return Int(window.remainingPercent.rounded())
        } else {
            return Int(window.usedPercent.rounded())
        }
    }

    private var displayProgress: Double {
        if displayMode == DisplayMode.remaining.rawValue {
            return 1.0 - window.normalizedProgress
        } else {
            return window.normalizedProgress
        }
    }

    private var title: String {
        let isChinese = language == AppLanguage.chinese.rawValue
        let isRemaining = displayMode == DisplayMode.remaining.rawValue

        switch window.kind {
        case .fiveHours:
            if isRemaining {
                return isChinese ? "5 h剩余" : "5H LEFT"
            } else {
                return isChinese ? "5h 用量" : "5H USAGE"
            }
        case .weekly:
            if isRemaining {
                return isChinese ? "7 d 剩余" : "7D LEFT"
            } else {
                return isChinese ? "7d 用量" : "7D USAGE"
            }
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
