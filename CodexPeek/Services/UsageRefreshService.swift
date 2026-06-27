import Foundation
import SwiftUI

@MainActor
final class UsageRefreshService: ObservableObject {
    @Published private(set) var state: UsageState = .idle {
        didSet { onStateChange?(state) }
    }

    @AppStorage("autoRefreshEnabled") var autoRefreshEnabled = true
    @AppStorage("refreshIntervalSeconds") var refreshIntervalSeconds = 120.0

    static let minimumRefreshIntervalSeconds = 60.0
    static let maximumRefreshIntervalSeconds = 300.0

    var onStateChange: ((UsageState) -> Void)?

    private let provider: CodexUsageProvider
    private var refreshTask: Task<UsageState, Never>?
    private var activityRefreshTask: Task<Void, Never>?
    private var activityMonitor: CodexActivityMonitor?
    private var lastActivityRefreshAt: Date?

    init(provider: CodexUsageProvider) {
        self.provider = provider
    }

    func start() {
        normalizeRefreshInterval()
        Task { await refresh() }
        restartAutoRefresh()
    }

    func stop() {
        refreshTask?.cancel()
        activityRefreshTask?.cancel()
        activityMonitor?.stop()
    }

    func restartAutoRefresh() {
        activityRefreshTask?.cancel()
        activityMonitor?.stop()
        guard autoRefreshEnabled else { return }

        normalizeRefreshInterval()
        let monitor = CodexActivityMonitor { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleActivityRefresh()
            }
        }
        activityMonitor = monitor
        monitor.start()
    }

    func refresh() async {
        guard refreshTask == nil else { return }

        let previous = state.latestUsage
        state = .loading(previous: previous)

        refreshTask = Task { [provider] in
            do {
                return .loaded(try await provider.fetchUsage())
            } catch let error as UsageError {
                return .failed(error, previous: previous)
            } catch {
                return .failed(.network(error.localizedDescription), previous: previous)
            }
        }

        if let result = await refreshTask?.value {
            state = result
            if case .loaded = result {
                lastActivityRefreshAt = Date()
            }
        }
        refreshTask = nil
    }

    func setRefreshIntervalSeconds(_ value: Double) {
        refreshIntervalSeconds = min(
            max(value, Self.minimumRefreshIntervalSeconds),
            Self.maximumRefreshIntervalSeconds
        )
        restartAutoRefresh()
    }

    private func normalizeRefreshInterval() {
        let normalized = min(
            max(refreshIntervalSeconds, Self.minimumRefreshIntervalSeconds),
            Self.maximumRefreshIntervalSeconds
        )
        if normalized != refreshIntervalSeconds {
            refreshIntervalSeconds = normalized
        }
    }

    private func scheduleActivityRefresh() {
        guard autoRefreshEnabled else { return }

        activityRefreshTask?.cancel()
        normalizeRefreshInterval()

        let minimumDelay: TimeInterval
        if let lastActivityRefreshAt {
            let elapsed = Date().timeIntervalSince(lastActivityRefreshAt)
            minimumDelay = max(0, refreshIntervalSeconds - elapsed)
        } else {
            minimumDelay = 0
        }

        // Codex 一次会话会连续写入多个文件，稍微防抖可以避免短时间内重复请求。
        let delay = max(3, minimumDelay)
        activityRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}
