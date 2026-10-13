import Foundation

public struct MarkdownHeading: Identifiable, Equatable, Codable {
    public var id: String
    public var title: String
    public var level: Int
    public var line: Int
    public var offset: Int
}

public struct WritingStatistics: Equatable {
    public let words: Int
    public let characters: Int
    public let lines: Int
    public let readingMinutes: Int

    public init(text: String) {
        let body = FrontMatter.split(text).body
        let cjk = body.unicodeScalars.filter(Self.isCJK).count
        let latin = body.replacingOccurrences(of: "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}]", with: " ", options: .regularExpression)
        let tokens = latin.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) } }.count
        words = cjk + tokens
        characters = body.filter { !$0.isWhitespace }.count
        lines = text.components(separatedBy: "\n").count
        readingMinutes = words == 0 ? 0 : max(1, Int(ceil(Double(cjk) / 300 + Double(tokens) / 220)))
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        (0x3400...0x9FFF).contains(scalar.value) || (0x20000...0x323AF).contains(scalar.value)
            || (0x3040...0x30FF).contains(scalar.value) || (0xAC00...0xD7AF).contains(scalar.value)
    }
}

public enum MarkdownAnalysis {
    // ===== 提取目录并跳过代码块与文章元信息 =====
    public static func headings(in text: String) -> [MarkdownHeading] {
        let parts = FrontMatter.split(text)
        let prefixLines = parts.prefix.components(separatedBy: "\n").count - 1
        let lines = parts.body.components(separatedBy: "\n")
        var results: [MarkdownHeading] = []
        var fence: Character?
        var fenceLength = 0
        var offset = parts.prefix.utf16.count
        var usedIDs: [String: Int] = [:]
        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            defer { offset += rawLine.utf16.count + 1 }
            if let first = line.first, first == "`" || first == "~" {
                let length = line.prefix(while: { $0 == first }).count
                if length >= 3 {
                    if fence == nil { fence = first; fenceLength = length }
                    else if fence == first && length >= fenceLength && line.dropFirst(length).trimmingCharacters(in: .whitespaces).isEmpty { fence = nil }
                    continue
                }
            }
            guard fence == nil, !rawLine.hasPrefix("    "), !rawLine.hasPrefix("\t") else { continue }
            let level = line.prefix(while: { $0 == "#" }).count
            var headingTitle: String?
            var headingLevel = level
            if (1...6).contains(level), line.dropFirst(level).first?.isWhitespace == true {
                headingTitle = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\\s+#+\\s*$", with: "", options: .regularExpression)
            } else if index + 1 < lines.count, !line.isEmpty {
                let underline = lines[index + 1].trimmingCharacters(in: .whitespaces)
                if underline.count >= 1 && (underline.allSatisfy { $0 == "=" } || underline.allSatisfy { $0 == "-" }) {
                    headingTitle = line; headingLevel = underline.first == "=" ? 1 : 2
                }
            }
            guard let rawTitle = headingTitle else { continue }
            let title = rawTitle.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "[*_`~]", with: "", options: .regularExpression)
            let base = slug(title)
            let duplicate = usedIDs[base, default: 0]
            usedIDs[base] = duplicate + 1
            results.append(MarkdownHeading(id: duplicate == 0 ? base : "\(base)-\(duplicate)", title: title,
                level: headingLevel, line: index + prefixLines + 1, offset: offset))
        }
        return results
    }

    public static func title(in text: String, fallback: String = "未命名文章") -> String {
        if let title = FrontMatter.value("title", in: text), !title.isEmpty { return title }
        return headings(in: text).first?.title ?? fallback
    }

    public static func slug(_ title: String) -> String {
        let cleaned = title.lowercased().replacingOccurrences(of: "[^\\p{L}\\p{N}\\s_-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
        return cleaned.isEmpty ? "section" : cleaned
    }
}
