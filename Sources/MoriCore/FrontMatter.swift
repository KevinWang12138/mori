import Foundation

public struct FrontMatterParts: Equatable {
    public let prefix: String
    public let yaml: String
    public let body: String
}

public enum FrontMatter {
    // ===== 只在文件开头识别 YAML，保留原始分隔符与换行 =====
    public static func split(_ text: String) -> FrontMatterParts {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---", lines.count > 1,
            let end = lines.indices.dropFirst().first(where: {
                ["---", "..."].contains(lines[$0].trimmingCharacters(in: .whitespacesAndNewlines))
            }) else { return FrontMatterParts(prefix: "", yaml: "", body: text) }
        let prefix = lines[0...end].joined(separator: "\n") + (end < lines.count - 1 ? "\n" : "")
        let yaml = lines[1..<end].joined(separator: "\n")
        let body = end + 1 < lines.count ? lines[(end + 1)...].joined(separator: "\n") : ""
        return FrontMatterParts(prefix: prefix, yaml: yaml, body: body)
    }

    public static func value(_ key: String, in text: String) -> String? {
        for line in split(text).yaml.components(separatedBy: "\n") {
            guard line.hasPrefix(key + ":") else { continue }
            let value = String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("\""), let data = value.data(using: .utf8), let decoded = try? JSONDecoder().decode(String.self, from: data) { return decoded }
            if value.hasPrefix("'") && value.hasSuffix("'") { return String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'") }
            return value
        }
        return nil
    }

    public static func template(style: BlogTemplate, title: String, date: String) -> String {
        let quotedTitle = quote(title)
        switch style {
        case .blank: return "# \(title)\n\n"
        case .astro: return "---\ntitle: \(quotedTitle)\ndescription: \"\"\npubDate: \(date)\ntags: []\ndraft: true\n---\n\n# \(title)\n\n"
        case .hugo: return "---\ntitle: \(quotedTitle)\ndate: \(date)\nslug: \"\"\ntags: []\ncategories: []\ndraft: true\n---\n\n# \(title)\n\n"
        case .jekyll: return "---\nlayout: post\ntitle: \(quotedTitle)\ndate: \(date)\ncategories: []\ntags: []\n---\n\n# \(title)\n\n"
        }
    }

    private static func quote(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value), let encoded = String(data: data, encoding: .utf8) else { return "\"\"" }
        return encoded
    }
}

public enum BlogTemplate: String, CaseIterable, Codable, Identifiable {
    case blank, astro, hugo, jekyll
    public var id: String { rawValue }
    public var label: String {
        switch self { case .blank: return "空白文章"; case .astro: return "Astro"; case .hugo: return "Hugo"; case .jekyll: return "Jekyll" }
    }
}
