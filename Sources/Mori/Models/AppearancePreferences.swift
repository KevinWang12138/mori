import SwiftUI

enum WritingTheme: String, Codable, CaseIterable, Identifiable {
    case paper, sage, night
    var id: String { rawValue }
    var label: String { switch self { case .paper: return L10n.text("暖纸"); case .sage: return L10n.text("青苔"); case .night: return L10n.text("墨夜") } }
    var background: String { switch self { case .paper: return "#F1EFE9"; case .sage: return "#E5EBE4"; case .night: return "#161D1B" } }
    var surface: String { switch self { case .paper: return "#FFFEFA"; case .sage: return "#F7FAF5"; case .night: return "#202925" } }
    var text: String { self == .night ? "#E2E9E2" : "#28362E" }
    var muted: String { self == .night ? "#A0B4A5" : "#778377" }
    var accent: String { self == .night ? "#ADCBAF" : "#3F654F" }
    var scheme: ColorScheme { self == .night ? .dark : .light }
}

enum WallpaperKind: String, Codable, CaseIterable, Identifiable {
    case none, forest, custom
    var id: String { rawValue }
    var label: String { switch self { case .none: return L10n.text("纯色"); case .forest: return L10n.text("林间晨雾"); case .custom: return L10n.text("自选图片") } }
}

enum WallpaperFit: String, Codable, CaseIterable, Identifiable {
    case cover, contain, tile
    var id: String { rawValue }
    var label: String { switch self { case .cover: return L10n.text("铺满"); case .contain: return L10n.text("完整显示"); case .tile: return L10n.text("平铺") } }
}

enum WritingFont: String, Codable, CaseIterable, Identifiable {
    case editorial, system, song
    var id: String { rawValue }
    var label: String { switch self { case .editorial: return L10n.text("书卷衬线"); case .system: return L10n.text("简洁无衬线"); case .song: return L10n.text("中文宋体") } }
    var css: String {
        switch self {
        case .editorial: return "'Iowan Old Style', 'Palatino', 'Songti SC', serif"
        case .system: return "-apple-system, 'PingFang SC', sans-serif"
        case .song: return "'Songti SC', 'STSong', 'Iowan Old Style', serif"
        }
    }
}

struct AppearancePreferences: Codable, Equatable {
    var theme: WritingTheme = .paper
    var wallpaper: WallpaperKind = .none
    var customWallpaperPath: String?
    var fit: WallpaperFit = .cover
    var backgroundColor = "#F1EFE9"
    var overlayColor = "#F1EFE9"
    var wallpaperOpacity = 0.82
    var blur = 2.0
    var saturation = 0.85
    var overlayOpacity = 0.18
    var scale = 1.0
    var positionX = 0.5
    var positionY = 0.5
    var paperOpacity = 0.96
    var sidebarOpacity = 0.95
    var font: WritingFont = .editorial
    var fontSize = 18.0
    var lineHeight = 1.85
    var pageWidth = 760.0
    var autosave = true
    var spellcheck = true
    var showLineNumbers = true
    var wordGoal = 1000
    var customCSS = ""

    // ===== 限制从主题文件导入的数值，保证界面始终可读 =====
    mutating func normalize() {
        wallpaperOpacity = min(1, max(0, wallpaperOpacity)); overlayOpacity = min(1, max(0, overlayOpacity))
        paperOpacity = min(1, max(0.25, paperOpacity)); sidebarOpacity = min(1, max(0.35, sidebarOpacity))
        blur = min(40, max(0, blur)); saturation = min(2, max(0, saturation)); scale = min(3, max(0.5, scale))
        positionX = min(1, max(0, positionX)); positionY = min(1, max(0, positionY))
        fontSize = min(32, max(13, fontSize)); lineHeight = min(2.4, max(1.3, lineHeight)); pageWidth = min(1200, max(480, pageWidth))
        wordGoal = min(100000, max(100, wordGoal))
        if !Self.validHex(backgroundColor) { backgroundColor = theme.background }
        if !Self.validHex(overlayColor) { overlayColor = theme.background }
        customCSS = String(customCSS.prefix(100000))
    }

    private static func validHex(_ value: String) -> Bool {
        value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255, opacity: 1)
    }

    var rgbHex: String {
        guard let converted = NSColor(self).usingColorSpace(.sRGB) else { return "#F1EFE9" }
        return String(format: "#%02X%02X%02X", Int(converted.redComponent * 255), Int(converted.greenComponent * 255), Int(converted.blueComponent * 255))
    }
}
