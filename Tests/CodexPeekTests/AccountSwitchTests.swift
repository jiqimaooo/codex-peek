import XCTest
@testable import CodexPeek

final class AccountSwitchTests: XCTestCase {
    func testAuthStoreUsesAccountIdAsStableIdentity() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let authURL = directory.appendingPathComponent("auth.json")
        try Data(#"{"tokens":{"access_token":"token-a","account_id":"account-a"}}"#.utf8)
            .write(to: authURL)

        let store = AuthStore(authFileURL: authURL)
        let firstIdentifier = store.currentAccountIdentifier()
        XCTAssertNotNil(firstIdentifier)

        try Data(#"{"tokens":{"access_token":"token-b","account_id":"account-b"}}"#.utf8)
            .write(to: authURL)
        let secondIdentifier = store.currentAccountIdentifier()
        XCTAssertNotNil(secondIdentifier)
        XCTAssertNotEqual(firstIdentifier, secondIdentifier)
    }

    func testAuthStoreDetectsDifferentUsersInSameWorkspace() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let authURL = directory.appendingPathComponent("auth.json")
        try writeAuth(userId: "user-a", accountId: "shared-workspace", to: authURL)
        let store = AuthStore(authFileURL: authURL)
        let firstIdentifier = store.currentAccountIdentifier()

        try writeAuth(userId: "user-b", accountId: "shared-workspace", to: authURL)
        let secondIdentifier = store.currentAccountIdentifier()

        XCTAssertNotNil(firstIdentifier)
        XCTAssertNotNil(secondIdentifier)
        XCTAssertNotEqual(firstIdentifier, secondIdentifier)
    }

    func testCodexMonitorObservesAuthFileChanges() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let changed = expectation(description: "Codex auth file change observed")
        let monitor = CodexActivityMonitor(codexHomeURL: directory, latency: 0.1) {
            changed.fulfill()
        }
        monitor.start()
        defer { monitor.stop() }

        try Data(#"{"tokens":{"access_token":"token","account_id":"account"}}"#.utf8)
            .write(to: directory.appendingPathComponent("auth.json"))

        wait(for: [changed], timeout: 3)
    }

    @MainActor
    func testAccountChangeReplacesPreviousUsage() async {
        let oldUsage = makeUsage(fiveHourUsed: 10, weeklyUsed: 20)
        let newUsage = makeUsage(fiveHourUsed: 30, weeklyUsed: 40)
        let provider = SequenceUsageProvider(results: [.success(oldUsage), .success(newUsage)])
        let service = UsageRefreshService(provider: provider)

        await service.refresh()
        XCTAssertEqual(service.state.latestUsage, oldUsage)

        await service.refreshAfterAccountChange()
        XCTAssertEqual(service.state.latestUsage, newUsage)
    }

    @MainActor
    func testAccountChangeFailureDoesNotKeepOldAccountUsage() async {
        let oldUsage = makeUsage(fiveHourUsed: 10, weeklyUsed: 20)
        let provider = SequenceUsageProvider(results: [
            .success(oldUsage),
            .failure(.network("offline"))
        ])
        let service = UsageRefreshService(provider: provider)

        await service.refresh()
        XCTAssertEqual(service.state.latestUsage, oldUsage)

        await service.refreshAfterAccountChange()
        XCTAssertNil(service.state.latestUsage)
        XCTAssertEqual(service.state.error, .network("offline"))
    }

    private func makeUsage(fiveHourUsed: Double, weeklyUsed: Double) -> CodexUsage {
        CodexUsage(
            fiveHour: UsageWindow(
                kind: .fiveHours,
                usedPercent: fiveHourUsed,
                resetsAt: nil,
                totalDescription: "\(fiveHourUsed)% / 100%"
            ),
            weekly: UsageWindow(
                kind: .weekly,
                usedPercent: weeklyUsed,
                resetsAt: nil,
                totalDescription: "\(weeklyUsed)% / 100%"
            ),
            dataSource: "test",
            updatedAt: Date()
        )
    }

    private func writeAuth(userId: String, accountId: String, to url: URL) throws {
        let payload = [
            "https://api.openai.com/auth": [
                "chatgpt_user_id": userId
            ]
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        let encodedPayload = payloadData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let token = "header.\(encodedPayload).signature"
        let auth = [
            "tokens": [
                "access_token": token,
                "account_id": accountId
            ]
        ]
        try JSONSerialization.data(withJSONObject: auth).write(to: url)
    }
}

private final class SequenceUsageProvider: CodexUsageProvider {
    let sourceName = "test"
    private var results: [Result<CodexUsage, UsageError>]

    init(results: [Result<CodexUsage, UsageError>]) {
        self.results = results
    }

    func fetchUsage() async throws -> CodexUsage {
        guard !results.isEmpty else {
            throw UsageError.providerUnavailable("No result")
        }
        return try results.removeFirst().get()
    }
}
