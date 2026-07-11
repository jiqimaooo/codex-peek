import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var refreshService: UsageRefreshService
    @AppStorage("appLanguage") private var language = AppLanguage.chinese.rawValue
    @StateObject private var updateService = UpdateService()
    @State private var showUpToDateMessage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let usage = refreshService.state.latestUsage {
                UsageCardView(window: usage.fiveHour, language: language)
                UsageCardView(window: usage.weekly, language: language)
                
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(title: L(.lastUpdated, language), value: DateFormatter.usageTimestamp.string(from: usage.updatedAt))
                }
                .font(.system(size: 12))
            } else if refreshService.state.isLoading {
                loadingView
            } else {
                errorView
            }

            Divider()

            updateStatusView

            bottomBar
        }
        .padding(18)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task {
                await updateService.checkForUpdates(silent: true)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L(.codexUsage, language))
                    .font(.system(size: 18, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            Spacer()
            Button {
                Task { await refreshService.refresh() }
            } label: {
                Image(systemName: refreshService.state.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(refreshService.state.isLoading)
            .help(L(.refresh, language))
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(L(.readingUsage, language))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var errorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L(.unableToReadUsage, language))
                .font(.system(size: 14, weight: .semibold))
            Text(refreshService.state.error?.localizedDescription ?? L(.unknownError, language))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateService.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L(.checkingForUpdates, language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .updateAvailable(let version, _):
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                Text(L(.updateAvailable(version), language))
                    .font(.system(size: 11))
                Spacer()
                Button(L(.update, language)) {
                    updateService.startUpdate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        case .noUpdateAvailable:
            if showUpToDateMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L(.noUpdateAvailable, language))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text(L(.downloadingUpdate(String(format: "%.0f%%", progress * 100)), language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .controlSize(.small)
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L(.installingUpdate, language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .error(let errorMsg):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(L(.updateError(errorMsg), language))
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(L(.quit, language)) {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)

            Spacer()

            updateButton

            Button {
                SettingsWindowService.show(refreshService: refreshService)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(L(.settings, language))
        }
        .font(.system(size: 12))
    }

    private var updateButton: some View {
        Button {
            triggerUpdateAction()
        } label: {
            updateButtonIcon
        }
        .buttonStyle(.borderless)
        .disabled(isUpdateActionDisabled)
        .help(L(.update, language))
    }

    private var updateButtonIcon: some View {
        Group {
            switch updateService.state {
            case .idle, .noUpdateAvailable:
                Image(systemName: "arrow.down.circle")
            case .checking:
                Image(systemName: "arrow.triangle.2.circlepath")
            case .updateAvailable:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.secondary)
            case .installing:
                Image(systemName: "arrow.down.circle.fill")
            case .error:
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
            }
        }
    }

    private var isUpdateActionDisabled: Bool {
        switch updateService.state {
        case .checking, .downloading, .installing:
            return true
        default:
            return false
        }
    }

    private func triggerUpdateAction() {
        switch updateService.state {
        case .updateAvailable:
            updateService.startUpdate()
        default:
            showUpToDateMessage = true
            Task {
                await updateService.checkForUpdates()
                // Hide up-to-date message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showUpToDateMessage = false
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private var statusText: String {
        if refreshService.state.isLoading { return L(.refreshing, language) }
        if let error = refreshService.state.error, refreshService.state.latestUsage == nil {
            return error == .notLoggedIn ? L(.notLoggedIn, language) : L(.unavailable, language)
        }
        guard let status = refreshService.state.latestUsage?.status else {
            return L(.idle, language)
        }
        switch status {
        case .normal:
            return L(.normal, language)
        case .nearLimit:
            return L(.nearLimit, language)
        case .limited:
            return L(.limited, language)
        }
    }

    private var statusColor: Color {
        switch refreshService.state.latestUsage?.status {
        case .normal:
            return .secondary
        case .nearLimit:
            return .orange
        case .limited:
            return AppColors.quotaRed
        case .none:
            return refreshService.state.error == nil ? .secondary : AppColors.quotaRed
        }
    }
}
