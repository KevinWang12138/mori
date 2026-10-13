import Foundation

enum AppPaths {
    // ===== 文档截图实例使用独立资料目录，避免读取用户文章和设置 =====
    static let support: URL = {
        if Bundle.main.bundleIdentifier == "com.kevin.mori.documentation",
            let directory = ProcessInfo.processInfo.environment["MORI_DOCUMENTATION_DIRECTORY"] {
            return URL(fileURLWithPath: directory, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mori", isDirectory: true)
    }()
    static let resources: URL = {
        if let base = Bundle.main.resourceURL,
            let bundle = Bundle(url: base.appendingPathComponent("Mori_Mori.bundle")),
            let resourceURL = bundle.resourceURL {
            return resourceURL.appendingPathComponent("Resources", isDirectory: true)
        }
        return Bundle.module.resourceURL!.appendingPathComponent("Resources", isDirectory: true)
    }()
    static let web = resources.appendingPathComponent("Web", isDirectory: true)
    static let backgrounds = support.appendingPathComponent("Backgrounds", isDirectory: true)
}
