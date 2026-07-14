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
    private var refreshID: UUID?
    private var activityRefreshTask: Task<Void, Never>?
    private var activityMonitor: CodexActivityMonitor?
    private let authStore = AuthStore()
    private var observedAccountIdentifier: String?
    private var lastActivityRefreshAt: Date?

    init(provider: CodexUsageProvider) {
        self.provider = provider
    }

    func start() {
        normalizeRefreshInterval()
        observedAccountIdentifier = authStore.currentAccountIdentifier()
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

        normalizeRefreshInterval()
        let monitor = CodexActivityMonitor { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleCodexActivity()
            }
        }
        activityMonitor = monitor
        monitor.start()
    }

    func refresh(clearPrevious: Bool = false) async {
        if clearPrevious {
            invalidateCurrentRefresh()
        }
        guard refreshTask == nil else { return }

        let previous = clearPrevious ? nil : state.latestUsage
        state = .loading(previous: previous)

        let id = UUID()
        let task = Task<UsageState, Never> { [provider] in
            do {
                return .loaded(try await provider.fetchUsage())
            } catch let error as UsageError {
                return .failed(error, previous: previous)
            } catch {
                return .failed(.network(error.localizedDescription), previous: previous)
            }
        }
        refreshID = id
        refreshTask = task

        let result = await task.value
        guard refreshID == id else { return }

        state = result
        if case .loaded = result {
            lastActivityRefreshAt = Date()
        }
        refreshTask = nil
        refreshID = nil
    }

    func refreshAfterAccountChange() async {
        activityRefreshTask?.cancel()
        lastActivityRefreshAt = nil
        await refresh(clearPrevious: true)
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

    private func handleCodexActivity() async {
        let currentAccountIdentifier = authStore.currentAccountIdentifier()
        if currentAccountIdentifier != observedAccountIdentifier {
            observedAccountIdentifier = currentAccountIdentifier
            await refreshAfterAccountChange()
            return
        }

        guard autoRefreshEnabled else { return }
        scheduleActivityRefresh()
    }

    private func invalidateCurrentRefresh() {
        refreshID = nil
        refreshTask?.cancel()
        refreshTask = nil
    }
}
