import Foundation

enum UsageState: Equatable {
    case idle
    case loading(previous: CodexUsage?)
    case loaded(CodexUsage)
    case failed(UsageError, previous: CodexUsage?)

    var latestUsage: CodexUsage? {
        switch self {
        case .idle:
            return nil
        case .loading(let previous):
            return previous
        case .loaded(let usage):
            return usage
        case .failed(_, let previous):
            return previous
        }
    }

    var error: UsageError? {
        if case .failed(let error, _) = self { return error }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

enum UsageError: LocalizedError, Equatable {
    case notLoggedIn
    case authFileUnreadable(String)
    case tokenRefreshFailed(String)
    case invalidResponse(String)
    case network(String)
    case permissionDenied
    case providerUnavailable(String)
    case allProvidersFailed([String])

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "未找到 Codex 登录凭证，请先运行 Codex CLI 并完成登录。"
        case .authFileUnreadable(let path):
            return "无法读取认证文件：\(path)"
        case .tokenRefreshFailed(let message):
            return "刷新登录凭证失败：\(message)"
        case .invalidResponse(let message):
            return "Codex 用量接口返回格式异常：\(message)"
        case .network(let message):
            return "网络请求失败：\(message)"
        case .permissionDenied:
            return "当前账号没有读取 Codex 用量的权限。"
        case .providerUnavailable(let message):
            return message
        case .allProvidersFailed(let messages):
            return messages.joined(separator: "\n")
        }
    }
}
