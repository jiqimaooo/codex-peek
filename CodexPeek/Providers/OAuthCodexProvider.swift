import Foundation

struct OAuthCodexProvider: CodexUsageProvider {
    let sourceName = "~/.codex/auth.json + OpenAI Codex Usage API"

    private let authStore: AuthStore
    private let session: URLSession
    private let decoder: JSONDecoder

    init(authStore: AuthStore = AuthStore(), session: URLSession = .shared) {
        self.authStore = authStore
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }

            let string = try container.decode(String.self)
            let formatters = [
                ISO8601DateFormatter.usageWithFractionalSeconds,
                ISO8601DateFormatter.usageDefault
            ]
            for formatter in formatters {
                if let date = formatter.date(from: string) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期：\(string)")
        }
    }

    func fetchUsage() async throws -> CodexUsage {
        let auth = try authStore.loadCodexAuth()
        guard let token = auth.tokens?.accessToken ?? auth.tokens?.idToken, !token.isEmpty else {
            throw UsageError.notLoggedIn
        }

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexPeek/1.0", forHTTPHeaderField: "User-Agent")
        if let accountId = auth.tokens?.accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UsageError.invalidResponse("缺少 HTTP 响应。")
            }

            switch httpResponse.statusCode {
            case 200:
                let payload = try decoder.decode(CodexUsageAPIResponse.self, from: data)
                return try payload.toCodexUsage(source: sourceName)
            case 401:
                throw UsageError.notLoggedIn
            case 403:
                throw UsageError.permissionDenied
            default:
                throw UsageError.network("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as UsageError {
            throw error
        } catch let error as DecodingError {
            throw UsageError.invalidResponse(error.localizedDescription)
        } catch {
            throw UsageError.network(error.localizedDescription)
        }
    }
}

private struct CodexUsageAPIResponse: Decodable {
    let rateLimit: RateLimitDetails?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
    }

    func toCodexUsage(source: String) throws -> CodexUsage {
        let normalized = RateWindowNormalizer.normalize(
            primary: rateLimit?.primaryWindow?.toWindow(),
            secondary: rateLimit?.secondaryWindow?.toWindow()
        )
        guard let fiveHourWindow = normalized.primary,
              let weeklyWindow = normalized.secondary
        else {
            throw UsageError.invalidResponse("响应中缺少 Codex 5 小时或周用量窗口。")
        }

        let now = Date()
        let fiveHour = UsageWindow(
            kind: .fiveHours,
            usedPercent: fiveHourWindow.usedPercent,
            resetsAt: fiveHourWindow.resetsAt,
            totalDescription: fiveHourWindow.totalDescription
        )
        let weekly = UsageWindow(
            kind: .weekly,
            usedPercent: weeklyWindow.usedPercent,
            resetsAt: weeklyWindow.resetsAt,
            totalDescription: weeklyWindow.totalDescription
        )

        return CodexUsage(
            fiveHour: fiveHour,
            weekly: weekly,
            dataSource: source,
            updatedAt: now
        )
    }
}

private struct RateLimitDetails: Decodable {
    let primaryWindow: WindowSnapshot?
    let secondaryWindow: WindowSnapshot?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct WindowSnapshot: Decodable {
    let usedPercent: Double
    let resetAt: Int
    let limitWindowSeconds: Int

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAt = "reset_at"
        case limitWindowSeconds = "limit_window_seconds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.usedPercent = try container.flexibleDouble(forKey: .usedPercent)
        self.resetAt = try container.flexibleInt(forKey: .resetAt)
        self.limitWindowSeconds = try container.flexibleInt(forKey: .limitWindowSeconds)
    }

    func toWindow() -> ProviderRateWindow {
        ProviderRateWindow(
            usedPercent: usedPercent,
            windowMinutes: limitWindowSeconds / 60,
            resetsAt: Date(timeIntervalSince1970: TimeInterval(resetAt))
        )
    }
}

private struct ProviderRateWindow {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date

    var totalDescription: String {
        "\(usedPercent.cleanUsageString)% / 100%"
    }
}

private enum RateWindowNormalizer {
    static func normalize(
        primary: ProviderRateWindow?,
        secondary: ProviderRateWindow?
    ) -> (primary: ProviderRateWindow?, secondary: ProviderRateWindow?) {
        switch (primary, secondary) {
        case let (.some(primaryWindow), .some(secondaryWindow)):
            switch (role(for: primaryWindow), role(for: secondaryWindow)) {
            case (.session, .weekly), (.session, .unknown), (.unknown, .weekly):
                return (primaryWindow, secondaryWindow)
            case (.weekly, .session), (.weekly, .unknown):
                return (secondaryWindow, primaryWindow)
            default:
                return (primaryWindow, secondaryWindow)
            }
        case let (.some(primaryWindow), .none):
            return role(for: primaryWindow) == .weekly ? (nil, primaryWindow) : (primaryWindow, nil)
        case let (.none, .some(secondaryWindow)):
            return role(for: secondaryWindow) == .weekly ? (nil, secondaryWindow) : (secondaryWindow, nil)
        case (.none, .none):
            return (nil, nil)
        }
    }

    private enum WindowRole {
        case session
        case weekly
        case unknown
    }

    private static func role(for window: ProviderRateWindow) -> WindowRole {
        switch window.windowMinutes {
        case 300:
            return .session
        case 10080:
            return .weekly
        default:
            return .unknown
        }
    }
}

private extension KeyedDecodingContainer {
    func flexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? decode(String.self, forKey: key),
           let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "无法解析数字字段。")
    }

    func flexibleInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        if let value = try? decode(String.self, forKey: key),
           let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "无法解析整数字段。")
    }
}
