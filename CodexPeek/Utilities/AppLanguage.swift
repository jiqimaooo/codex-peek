import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }

    static func resolve(_ rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .chinese
    }
}

enum LocalizedText {
    static func text(_ key: Key, language rawValue: String) -> String {
        let language = AppLanguage.resolve(rawValue)
        switch (key, language) {
        case (.codexUsage, .chinese): return "Codex 用量"
        case (.codexUsage, .english): return "Codex Usage"
        case (.refreshing, .chinese): return "正在刷新"
        case (.refreshing, .english): return "Refreshing"
        case (.notLoggedIn, .chinese): return "未登录"
        case (.notLoggedIn, .english): return "Not Logged In"
        case (.unavailable, .chinese): return "不可用"
        case (.unavailable, .english): return "Unavailable"
        case (.idle, .chinese): return "空闲"
        case (.idle, .english): return "Idle"
        case (.normal, .chinese): return "正常"
        case (.normal, .english): return "Normal"
        case (.nearLimit, .chinese): return "接近限制"
        case (.nearLimit, .english): return "Near Limit"
        case (.limited, .chinese): return "已受限"
        case (.limited, .english): return "Limited"
        case (.refresh, .chinese): return "刷新"
        case (.refresh, .english): return "Refresh"
        case (.readingUsage, .chinese): return "正在读取 Codex 用量..."
        case (.readingUsage, .english): return "Reading Codex usage..."
        case (.unableToReadUsage, .chinese): return "无法读取用量"
        case (.unableToReadUsage, .english): return "Unable to read usage"
        case (.unknownError, .chinese): return "未知错误。"
        case (.unknownError, .english): return "Unknown error."
        case (.fiveHourUsage, .chinese): return "5 小时用量"
        case (.fiveHourUsage, .english): return "5h Usage"
        case (.fiveHourRemainingShort, .chinese): return "5h 剩余"
        case (.fiveHourRemainingShort, .english): return "5h Left"
        case (.weeklyUsage, .chinese): return "每周用量"
        case (.weeklyUsage, .english): return "Weekly Usage"
        case (.usedTotal, .chinese): return "已用 / 总量"
        case (.usedTotal, .english): return "Used / Total"
        case (.remaining, .chinese): return "剩余"
        case (.remaining, .english): return "Remaining"
        case (.reset, .chinese): return "重置"
        case (.reset, .english): return "Reset"
        case (.unknown, .chinese): return "未知"
        case (.unknown, .english): return "Unknown"
        case (.lastUpdated, .chinese): return "最近更新"
        case (.lastUpdated, .english): return "Last updated"
        case (.dataSource, .chinese): return "数据来源"
        case (.dataSource, .english): return "Data source"
        case (.autoRefresh, .chinese): return "使用时刷新"
        case (.autoRefresh, .english): return "Refresh on activity"
        case (.launchAtLogin, .chinese): return "开机启动"
        case (.launchAtLogin, .english): return "Launch at login"
        case (.language, .chinese): return "语言"
        case (.language, .english): return "Language"
        case (.settings, .chinese): return "设置"
        case (.settings, .english): return "Settings"
        case (.quit, .chinese): return "退出"
        case (.quit, .english): return "Quit"
        case (.about, .chinese): return "关于"
        case (.about, .english): return "About"
        case (.version, .chinese): return "版本"
        case (.version, .english): return "Version"
        case (.openSourceProject, .chinese): return "开源项目"
        case (.openSourceProject, .english): return "Open source project"
        case (.author, .chinese): return "作者"
        case (.author, .english): return "Author"
        case (.appDescription, .chinese): return "快速查看 Codex 剩余额度。"
        case (.appDescription, .english): return "A macOS menu bar utility for checking real Codex usage and remaining quota."
        case (.refreshEvery(let minutes), .chinese): return "最短间隔 \(minutes) 分钟"
        case (.refreshEvery(let minutes), .english): return "Minimum interval \(minutes) min"
        case (.update, .chinese): return "检查更新"
        case (.update, .english): return "Check for Updates"
        case (.checkingForUpdates, .chinese): return "正在检查更新..."
        case (.checkingForUpdates, .english): return "Checking for updates..."
        case (.updateAvailable(let version), .chinese): return "有新版本 \(version)"
        case (.updateAvailable(let version), .english): return "New version \(version)"
        case (.noUpdateAvailable, .chinese): return "已是最新版本"
        case (.noUpdateAvailable, .english): return "Up to date"
        case (.downloadingUpdate(let progress), .chinese): return "正在下载 \(progress)"
        case (.downloadingUpdate(let progress), .english): return "Downloading \(progress)"
        case (.installingUpdate, .chinese): return "正在安装更新..."
        case (.installingUpdate, .english): return "Installing update..."
        case (.updateError(let error), .chinese): return "更新失败: \(error)"
        case (.updateError(let error), .english): return "Update failed: \(error)"
        }
    }

    enum Key: Equatable {
        case codexUsage
        case refreshing
        case notLoggedIn
        case unavailable
        case idle
        case normal
        case nearLimit
        case limited
        case refresh
        case readingUsage
        case unableToReadUsage
        case unknownError
        case fiveHourUsage
        case fiveHourRemainingShort
        case weeklyUsage
        case usedTotal
        case remaining
        case reset
        case unknown
        case lastUpdated
        case dataSource
        case autoRefresh
        case launchAtLogin
        case language
        case settings
        case quit
        case about
        case version
        case openSourceProject
        case author
        case appDescription
        case refreshEvery(String)
        case update
        case checkingForUpdates
        case updateAvailable(String)
        case noUpdateAvailable
        case downloadingUpdate(String)
        case installingUpdate
        case updateError(String)
    }
}

func L(_ key: LocalizedText.Key, _ language: String) -> String {
    LocalizedText.text(key, language: language)
}
