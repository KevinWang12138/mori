import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var value: AppearancePreferences { didSet { persist() } }
    @Published var errorMessage: String?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "appearance"), let decoded = try? JSONDecoder().decode(AppearancePreferences.self, from: data) {
            var preferences = decoded; preferences.normalize(); value = preferences
        } else { value = AppearancePreferences() }
    }

    func selectTheme(_ theme: WritingTheme) {
        value.theme = theme; value.backgroundColor = theme.background; value.overlayColor = theme.background
    }

    // ===== 将用户背景拷贝到应用资料目录，移动原图后仍能使用 =====
    func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .webP]
        panel.prompt = "设为背景"; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let source = panel.url else { return }
        do {
            guard let image = NSImage(contentsOf: source), image.size.width > 0 else { throw CocoaError(.fileReadCorruptFile) }
            try FileManager.default.createDirectory(at: AppPaths.backgrounds, withIntermediateDirectories: true)
            let destination = AppPaths.backgrounds.appendingPathComponent(UUID().uuidString + "." + source.pathExtension)
            try FileManager.default.copyItem(at: source, to: destination)
            let oldPath = value.customWallpaperPath
            value.customWallpaperPath = destination.path; value.wallpaper = .custom
            if let oldPath, oldPath.hasPrefix(AppPaths.backgrounds.path + "/") { try? FileManager.default.removeItem(atPath: oldPath) }
        } catch { errorMessage = "背景图片没有导入成功。请换一张图片或检查文件权限。" }
    }

    func exportTheme() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Mori-写作主题.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var portable = value; portable.customWallpaperPath = nil
            if portable.wallpaper == .custom { portable.wallpaper = .none }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(portable).write(to: url, options: .atomic)
        } catch { errorMessage = "主题没有导出成功。请检查目标文件夹的权限。" }
    }

    func importTheme() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
            var imported = try JSONDecoder().decode(AppearancePreferences.self, from: data)
            imported.normalize(); imported.customWallpaperPath = value.customWallpaperPath
            if imported.wallpaper == .custom && imported.customWallpaperPath == nil { imported.wallpaper = .none }
            value = imported
        } catch { errorMessage = "无法读取这个主题。请使用 Mori 导出的主题文件。" }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "appearance") }
    }
}
