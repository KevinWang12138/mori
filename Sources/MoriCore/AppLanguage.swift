import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, english = "en", simplifiedChinese = "zh-CN"
    public var id: String { rawValue }
    public static let preferenceKey = "interfaceLanguage"

    // ===== 跟随首选系统语言，未支持的语言回退到英文 =====
    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        let primary = preferredLanguages.first?.lowercased() ?? "en"
        return primary.hasPrefix("zh") ? .simplifiedChinese : .english
    }

    // ===== 界面语言独立于主题与文章保存，兼容已有设置 =====
    public static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        defaults.string(forKey: preferenceKey).flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    public func save(to defaults: UserDefaults = .standard) { defaults.set(rawValue, forKey: Self.preferenceKey) }
}
