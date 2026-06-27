import SwiftUI

struct SettingsView: View {
    @ObservedObject var refreshService: UsageRefreshService
    @AppStorage("appLanguage") private var language = AppLanguage.chinese.rawValue

    var body: some View {
        Form {
            Stepper(
                L(.refreshEvery("\(Int(refreshService.refreshIntervalSeconds / 60))"), language),
                value: Binding(
                    get: { refreshService.refreshIntervalSeconds },
                    set: { refreshService.setRefreshIntervalSeconds($0) }
                ),
                in: UsageRefreshService.minimumRefreshIntervalSeconds...UsageRefreshService.maximumRefreshIntervalSeconds,
                step: 60
            )
            Picker(L(.language, language), selection: $language) {
                ForEach(AppLanguage.allCases) { appLanguage in
                    Text(appLanguage.title).tag(appLanguage.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
    }
}
