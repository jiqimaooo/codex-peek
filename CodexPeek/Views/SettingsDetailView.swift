import SwiftUI

struct SettingsDetailView: View {
    @ObservedObject var refreshService: UsageRefreshService
    @AppStorage("appLanguage") private var language = AppLanguage.chinese.rawValue
    @AppStorage("displayMode") private var displayMode = DisplayMode.usage.rawValue
    @State private var launchAtLoginEnabled = LaunchAtLoginService().isEnabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            appInfoSection

            VStack(spacing: 12) {
                // 偏好与展示卡片组
                VStack(alignment: .leading, spacing: 10) {
                    settingRow(icon: "percent", title: L(.displayMode, language)) {
                        Picker("", selection: $displayMode) {
                            ForEach(DisplayMode.allCases) { mode in
                                Text(mode.title(language: language)).tag(mode.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    Divider()
                        .opacity(0.5)
                    
                    settingRow(icon: "globe", title: L(.language, language)) {
                        Picker("", selection: $language) {
                            ForEach(AppLanguage.allCases) { appLanguage in
                                Text(appLanguage.title).tag(appLanguage.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))

                // 运行与刷新卡片组
                VStack(alignment: .leading, spacing: 10) {
                    settingRow(icon: "arrow.triangle.2.circlepath", title: L(.autoRefresh, language)) {
                        Toggle("", isOn: Binding(
                            get: { refreshService.autoRefreshEnabled },
                            set: { newValue in
                                refreshService.autoRefreshEnabled = newValue
                                refreshService.restartAutoRefresh()
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    
                    Divider()
                        .opacity(0.5)

                    
                    settingRow(icon: "play.circle", title: L(.launchAtLogin, language)) {
                        Toggle("", isOn: Binding(
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
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            }

            if let launchError {
                Text(launchError)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.quotaRed)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            footerSection
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var appInfoSection: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 57, height: 57)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Codex Peek")
                    .font(.system(size: 18, weight: .bold))
                Text(L(.appDescription, language))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            Divider()
                .opacity(0.6)
            
            HStack {
                Text(L(.version, language) + ": " + appVersion)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(L(.dataSource, language) + ": auth.json")
                    .foregroundStyle(.secondary)
                
                Text("|")
                    .foregroundStyle(.tertiary)
                
                Link("GitHub", destination: URL(string: "https://github.com/jiqimaooo/codex-peek")!)
                    .help(L(.openSourceProject, language))
            }
            .font(.system(size: 11))
            .padding(.top, 2)
        }
    }

    private func settingRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            
            Spacer()
            
            content()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
