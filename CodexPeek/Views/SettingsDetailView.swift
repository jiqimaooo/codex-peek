import SwiftUI

struct SettingsDetailView: View {
    @ObservedObject var refreshService: UsageRefreshService
    @AppStorage("appLanguage") private var language = AppLanguage.chinese.rawValue
    @AppStorage("displayMode") private var displayMode = DisplayMode.usage.rawValue
    @State private var launchAtLoginEnabled = LaunchAtLoginService().isEnabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            appInfoSection

            Divider()

            settingsSection

            if let launchError {
                Text(launchError)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.quotaRed)
                    .fixedSize(horizontal: false, vertical: true)
            }

            aboutSection
        }
        .padding(22)
        .frame(minWidth: 420, minHeight: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Codex Peek")
                .font(.system(size: 22, weight: .semibold))
            Text(L(.appDescription, language))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            detailRow(title: L(.dataSource, language), value: "~/.codex/auth.json + OpenAI Codex Usage API")
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(L(.autoRefresh, language), isOn: Binding(
                get: { refreshService.autoRefreshEnabled },
                set: { newValue in
                    refreshService.autoRefreshEnabled = newValue
                    refreshService.restartAutoRefresh()
                }
            ))

            Stepper(
                L(.refreshEvery("\(Int(refreshService.refreshIntervalSeconds / 60))"), language),
                value: Binding(
                    get: { refreshService.refreshIntervalSeconds },
                    set: { refreshService.setRefreshIntervalSeconds($0) }
                ),
                in: UsageRefreshService.minimumRefreshIntervalSeconds...UsageRefreshService.maximumRefreshIntervalSeconds,
                step: 60
            )

            Toggle(L(.launchAtLogin, language), isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { newValue in
                    do {
                        try LaunchAtLoginService().setEnabled(newValue)
                        launchAtLoginEnabled = newValue
                        launchError = nil
                    } catch {
                        launchAtLoginEnabled = LaunchAtLoginService().isEnabled
                        launchError = error.localizedDescription
                    }
                }
            ))

            HStack(spacing: 12) {
                Text(L(.displayMode, language))

                Picker("", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.title(language: language)).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            HStack(spacing: 12) {
                Text(L(.language, language))

                Picker("", selection: $language) {
                    ForEach(AppLanguage.allCases) { appLanguage in
                        Text(appLanguage.title).tag(appLanguage.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
            }
        }
        .font(.system(size: 13))
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.top, 2)

            Text(L(.about, language))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            detailRow(title: L(.version, language), value: appVersion)
            linkRow(title: L(.author, language), label: "GitHub", url: URL(string: "https://github.com/jiqimaooo/codex-peek")!)
        }
    }

    private func linkRow(title: String, label: String, url: URL) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Link(label, destination: url)
                .multilineTextAlignment(.trailing)
                .help(L(.openSourceProject, language))
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
        }
        .font(.system(size: 12))
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
