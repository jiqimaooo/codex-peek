import Foundation

enum UsageWindowKind: String, Codable, CaseIterable, Identifiable {
    case fiveHours
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveHours:
            return "5h Usage"
        case .weekly:
            return "Weekly Usage"
        }
    }
}

struct UsageWindow: Codable, Equatable, Identifiable {
    let kind: UsageWindowKind
    let usedPercent: Double
    let resetsAt: Date?
    let totalDescription: String

    var id: UsageWindowKind { kind }
    var remainingPercent: Double { max(0, 100 - usedPercent) }
    var normalizedProgress: Double { min(max(usedPercent / 100, 0), 1) }

    var status: LimitStatus {
        if usedPercent >= 90 { return .limited }
        if usedPercent >= 70 { return .nearLimit }
        return .normal
    }
}

enum LimitStatus: String, Codable {
    case normal = "Normal"
    case nearLimit = "Near Limit"
    case limited = "Limited"
}
