import Foundation

struct CodexAuth: Equatable {
    let tokens: CodexTokens?
    let lastRefresh: Date?
}

struct CodexTokens: Equatable {
    let idToken: String?
    let accessToken: String?
    let refreshToken: String?
    let accountId: String?
}

struct AuthStore {
    private let fileManager: FileManager
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadCodexAuth() throws -> CodexAuth {
        let path = authFileURL.path
        guard fileManager.fileExists(atPath: path) else {
            throw UsageError.notLoggedIn
        }

        let data: Data
        do {
            data = try Data(contentsOf: authFileURL)
        } catch {
            throw UsageError.authFileUnreadable(path)
        }

        do {
            return try parseAuth(data: data)
        } catch let error as UsageError {
            throw error
        } catch {
            throw UsageError.invalidResponse("认证文件结构不符合预期：\(error.localizedDescription)")
        }
    }

    private func parseAuth(data: Data) throws -> CodexAuth {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.invalidResponse("认证文件不是有效 JSON。")
        }

        if let apiKey = trimmedString(json["OPENAI_API_KEY"]) {
            return CodexAuth(
                tokens: CodexTokens(
                    idToken: nil,
                    accessToken: apiKey,
                    refreshToken: nil,
                    accountId: nil),
                lastRefresh: parseLastRefresh(json["last_refresh"]))
        }

        guard let tokens = json["tokens"] as? [String: Any] else {
            throw UsageError.notLoggedIn
        }

        let parsedTokens = CodexTokens(
            idToken: stringValue(in: tokens, snakeCaseKey: "id_token", camelCaseKey: "idToken"),
            accessToken: stringValue(in: tokens, snakeCaseKey: "access_token", camelCaseKey: "accessToken"),
            refreshToken: stringValue(in: tokens, snakeCaseKey: "refresh_token", camelCaseKey: "refreshToken"),
            accountId: stringValue(in: tokens, snakeCaseKey: "account_id", camelCaseKey: "accountId")
        )

        guard parsedTokens.accessToken?.isEmpty == false || parsedTokens.idToken?.isEmpty == false else {
            throw UsageError.notLoggedIn
        }

        return CodexAuth(tokens: parsedTokens, lastRefresh: parseLastRefresh(json["last_refresh"]))
    }

    private func stringValue(in dictionary: [String: Any], snakeCaseKey: String, camelCaseKey: String) -> String? {
        trimmedString(dictionary[snakeCaseKey]) ?? trimmedString(dictionary[camelCaseKey])
    }

    private func trimmedString(_ raw: Any?) -> String? {
        guard let value = raw as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseLastRefresh(_ raw: Any?) -> Date? {
        guard let value = trimmedString(raw) else { return nil }
        return ISO8601DateFormatter.usageWithFractionalSeconds.date(from: value)
            ?? ISO8601DateFormatter.usageDefault.date(from: value)
    }

    private var authFileURL: URL {
        let env = ProcessInfo.processInfo.environment
        if let codexHome = env["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !codexHome.isEmpty {
            return URL(fileURLWithPath: codexHome, isDirectory: true).appendingPathComponent("auth.json")
        }
        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
    }
}
