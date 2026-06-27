import SwiftUI

@main
struct CodexPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(refreshService: appDelegate.refreshService)
                .frame(width: 320)
        }
    }
}
