import Foundation

enum AppPaths {
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mori", isDirectory: true)
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
