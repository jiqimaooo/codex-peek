import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let refreshService = UsageRefreshService(provider: CodexUsageProviderChain())

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var statusHostingView: NSHostingView<MenuBarLabelView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 即使不是完整 app bundle 启动，也尽量保持只作为菜单栏工具运行。
        NSApp.setActivationPolicy(.accessory)

        configureStatusItem()
        configurePopover()

        refreshService.onStateChange = { [weak self] _ in
            self?.updateStatusLabel()
        }
        refreshService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshService.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateStatusLabel()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 448)
        popover.contentViewController = NSHostingController(
            rootView: UsagePopoverView(refreshService: refreshService)
        )
    }

    private func updateStatusLabel() {
        guard let button = statusItem?.button else { return }

        let rootView = MenuBarLabelView(state: refreshService.state)
        if let statusHostingView {
            statusHostingView.rootView = rootView
            statusHostingView.frame.size = statusHostingView.fittingSize
        } else {
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.frame.size = hostingView.fittingSize
            statusHostingView = hostingView
            button.addSubview(hostingView)
        }

        if let statusHostingView {
            statusHostingView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.deactivate(button.constraints)
            NSLayoutConstraint.activate([
                statusHostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                statusHostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                statusHostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
            let fittingWidth = max(78, statusHostingView.fittingSize.width)
            statusItem?.length = fittingWidth
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
