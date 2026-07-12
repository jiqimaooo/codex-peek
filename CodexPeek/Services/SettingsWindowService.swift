import AppKit
import SwiftUI

@MainActor
enum SettingsWindowService {
    private static var window: NSWindow?

    static func show(refreshService: UsageRefreshService) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.chinese.rawValue
        let controller = NSHostingController(
            rootView: SettingsDetailView(refreshService: refreshService)
        )
        let newWindow = NSWindow(contentViewController: controller)
        newWindow.title = L(.settings, language)
        newWindow.styleMask = [.titled, .closable, .miniaturizable]
        newWindow.setContentSize(NSSize(width: 420, height: 380))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        window = newWindow

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
