import Foundation

struct CodexUsage: Codable, Equatable {
    let fiveHour: UsageWindow
    let weekly: UsageWindow
    let dataSource: String
    let updatedAt: Date

    var status: LimitStatus {
        if fiveHour.status == .limited || weekly.status == .limited {
            return .limited
        }
        if fiveHour.status == .nearLimit || weekly.status == .nearLimit {
            return .nearLimit
        }
        return .normal
    }
}
