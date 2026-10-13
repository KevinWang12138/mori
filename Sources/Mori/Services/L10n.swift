import Foundation
import MoriCore

enum L10n {
    static var language: AppLanguage { AppLanguage.load().resolved() }
    static var locale: Locale { Locale(identifier: language.rawValue) }
    private static let english: [String: String] = {
        let url = AppPaths.resources.appendingPathComponent("Localization/en.json")
        guard let data = try? Data(contentsOf: url), let catalog = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return catalog
    }()
    private static let sourceKeys = Dictionary(english.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })

    // ===== 原文作为中文文案键，已显示的提示也能随语言重新翻译 =====
    static func text(_ key: String) -> String {
        let source = english[key] == nil ? sourceKeys[key] ?? key : key
        return language == .english ? english[source] ?? source : source
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    static func label(_ language: AppLanguage) -> String {
        switch language {
        case .system: return text("跟随系统")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}
