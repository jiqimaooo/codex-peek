import SwiftUI

struct MenuBarLabelView: View {
    let state: UsageState

    var body: some View {
        HStack(spacing: 5) {
            CodexMarkIcon(size: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text("5H: \(fiveHourText)")
                Text("7D: \(weeklyText)")
            }
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .frame(height: 22)
    }

    private var usage: CodexUsage? { state.latestUsage }

    private var fiveHourText: String {
        if let remainingPercent = usage?.fiveHour?.remainingPercent {
            return "\(Int(remainingPercent.rounded()))%"
        }
        if usage != nil || state.isLoading {
            return "--"
        }
        return "!"
    }

    private var weeklyText: String {
        if let remainingPercent = usage?.weekly?.remainingPercent {
            return "\(Int(remainingPercent.rounded()))%"
        }
        if usage != nil || state.isLoading {
            return "--"
        }
        return "!"
    }
}
