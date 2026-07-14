import CryptoKit
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
    let userId: String?
}

struct AuthStore {
    private let fileManager: FileManager
    private let overriddenAuthFileURL: URL?

    init(fileManager: FileManager = .default, authFileURL: URL? = nil) {
        self.fileManager = fileManager
        self.overriddenAuthFileURL = authFileURL
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

    func currentAccountIdentifier() -> String? {
        guard let tokens = try? loadCodexAuth().tokens else { return nil }
        let identityCandidates: [String?] = [tokens.userId, tokens.accountId]
        let identityParts: [String] = identityCandidates.compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        if !identityParts.isEmpty {
            return stableIdentifier(prefix: "account", value: identityParts.joined(separator: "|"))
        }
        if let subject = jwtSubject(tokens.idToken) ?? jwtSubject(tokens.accessToken) {
            return stableIdentifier(prefix: "subject", value: subject)
        }
        if let token = tokens.accessToken ?? tokens.idToken, !token.isEmpty {
            return stableIdentifier(prefix: "credential", value: token)
        }
        return nil
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
                    accountId: nil,
                    userId: nil),
                lastRefresh: parseLastRefresh(json["last_refresh"]))
        }

        guard let tokens = json["tokens"] as? [String: Any] else {
            throw UsageError.notLoggedIn
        }

        let idToken = stringValue(in: tokens, snakeCaseKey: "id_token", camelCaseKey: "idToken")
        let accessToken = stringValue(in: tokens, snakeCaseKey: "access_token", camelCaseKey: "accessToken")
        let parsedTokens = CodexTokens(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: stringValue(in: tokens, snakeCaseKey: "refresh_token", camelCaseKey: "refreshToken"),
            accountId: stringValue(in: tokens, snakeCaseKey: "account_id", camelCaseKey: "accountId"),
            userId: jwtUserId(accessToken) ?? jwtUserId(idToken)
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

    private func jwtSubject(_ token: String?) -> String? {
        guard let subject = jwtPayload(token)?["sub"] as? String,
              !subject.isEmpty
        else {
            return nil
        }
        return subject
    }

    private func jwtUserId(_ token: String?) -> String? {
        guard let payload = jwtPayload(token),
              let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        else {
            return nil
        }
        return trimmedString(auth["chatgpt_user_id"]) ?? trimmedString(auth["user_id"])
    }

    private func jwtPayload(_ token: String?) -> [String: Any]? {
        guard let token else { return nil }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return nil }

        var encoded = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)

        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func stableIdentifier(prefix: String, value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return "\(prefix):\(digest.map { String(format: "%02x", $0) }.joined())"
    }

    var authFileURL: URL {
        if let overriddenAuthFileURL {
            return overriddenAuthFileURL
        }
        let env = ProcessInfo.processInfo.environment
        if let codexHome = env["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !codexHome.isEmpty {
            return URL(fileURLWithPath: codexHome, isDirectory: true).appendingPathComponent("auth.json")
        }
        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
    }
}
