import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var refreshService: UsageRefreshService
    @AppStorage("appLanguage") private var language = AppLanguage.chinese.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let usage = refreshService.state.latestUsage {
                UsageCardView(window: usage.fiveHour, language: language)
                UsageCardView(window: usage.weekly, language: language)
                footer(usage: usage)
            } else if refreshService.state.isLoading {
                loadingView
            } else {
                errorView
            }
        }
        .padding(18)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
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

    private func footer(usage: CodexUsage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow(title: L(.lastUpdated, language), value: DateFormatter.usageTimestamp.string(from: usage.updatedAt))

            Divider()

            HStack {
                Button(L(.quit, language)) {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    SettingsWindowService.show(refreshService: refreshService)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help(L(.settings, language))
            }
        }
        .font(.system(size: 12))
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
