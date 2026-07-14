import Foundation

struct CodexUsage: Codable, Equatable {
    let fiveHour: UsageWindow?
    let weekly: UsageWindow?
    let dataSource: String
    let updatedAt: Date

    var status: LimitStatus {
        let statuses = [fiveHour?.status, weekly?.status].compactMap { $0 }
        if statuses.contains(.limited) {
            return .limited
        }
        if statuses.contains(.nearLimit) {
            return .nearLimit
        }
        return .normal
    }
}
