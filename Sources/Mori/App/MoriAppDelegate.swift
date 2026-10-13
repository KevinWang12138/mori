import AppKit

@MainActor
final class MoriAppDelegate: NSObject, NSApplicationDelegate {
    private weak var store: DocumentStore?
    private var pendingURLs: [URL] = []

    func connect(_ store: DocumentStore) {
        self.store = store
        for url in pendingURLs { store.open(url) }; pendingURLs.removeAll()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        if let store { for url in urls { store.open(url) } }
        else { pendingURLs.append(contentsOf: urls) }
    }

    // ===== 退出前刷新编辑器与恢复档案，写入失败时保留应用窗口 =====
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        store.prepareToQuit { success in sender.reply(toApplicationShouldTerminate: success) }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil) }
        return true
    }
}
