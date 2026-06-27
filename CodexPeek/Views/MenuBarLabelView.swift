import SwiftUI

struct MenuBarLabelView: View {
    let state: UsageState
    @AppStorage("appLanguage") private var language = AppLanguage.chinese.rawValue

    var body: some View {
        HStack(spacing: 5) {
            CodexMarkIcon(size: 16)
            Text(labelText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .frame(height: 22)
    }

    private var usage: CodexUsage? { state.latestUsage }

    private var labelText: String {
        if let remainingPercent = usage?.fiveHour.remainingPercent {
            return "\(L(.fiveHourRemainingShort, language)): \(Int(remainingPercent.rounded()))%"
        }
        if state.isLoading {
            return "\(L(.fiveHourRemainingShort, language)): --"
        }
        return "\(L(.fiveHourRemainingShort, language)): !"
    }

}
