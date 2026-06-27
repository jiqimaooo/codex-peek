import Foundation
import os

enum AppLog {
    static let usage = Logger(subsystem: "com.codexpeek.CodexPeek", category: "usage")

    static func sanitized(_ message: String) -> String {
        // 不记录 token、cookie、authorization 等敏感字段的原始值。
        message
            .replacingOccurrences(of: #"(?i)(authorization|token|cookie)["'=:\s]+[^,\s}]+"#, with: "$1=[REDACTED_SECRET]", options: .regularExpression)
    }
}
