import XCTest
@testable import MoriCore

final class MarkdownAnalysisTests: XCTestCase {
    func testOutlineSkipsFrontMatterAndBothFenceStylesAndDeduplicates() {
        let text = "---\ntitle: Blog\n---\n\n# First\n```md\n# not a heading\n```\n~~~\n## also not\n~~~\n## **第二章**\n# First\n"
        let headings = MarkdownAnalysis.headings(in: text)
        XCTAssertEqual(headings.map(\.title), ["First", "第二章", "First"])
        XCTAssertEqual(headings.map(\.id), ["first", "第二章", "first-1"])
        XCTAssertEqual(headings.map(\.line), [5, 12, 13])
        XCTAssertEqual((text as NSString).substring(from: headings[1].offset).hasPrefix("## **第二章**"), true)
    }

    func testClosingFenceMustNotContainText() {
        let text = "```\n```not-closing\n# still code\n```\n# real\n"
        XCTAssertEqual(MarkdownAnalysis.headings(in: text).map(\.title), ["real"])
    }

    func testSetextAndLinkTitles() {
        let text = "Title\n=====\n\n[Hello](https://example.com)\n----\n"
        XCTAssertEqual(MarkdownAnalysis.headings(in: text).map(\.title), ["Title", "Hello"])
        XCTAssertEqual(MarkdownAnalysis.headings(in: text).map(\.level), [1, 2])
    }

    func testFrontMatterPrefixIsPreservedExactly() {
        let text = "---\n# keep this comment\ntitle: \"你好\"\nnested:\n  custom: [a, b]\n...\n\n# body\n"
        let parts = FrontMatter.split(text)
        XCTAssertEqual(parts.prefix + parts.body, text)
        XCTAssertTrue(parts.yaml.contains("nested:\n  custom: [a, b]"))
        XCTAssertEqual(FrontMatter.value("title", in: text), "你好")
        XCTAssertEqual(FrontMatter.split("# heading\n\n---\n").prefix, "")
        XCTAssertEqual(FrontMatter.split("---\nnot closed").body, "---\nnot closed")
    }

    func testTemplateEscapesYAMLTitle() {
        let text = FrontMatter.template(style: .astro, title: "a: \"b\"\nnext", date: "2026-10-13")
        XCTAssertEqual(FrontMatter.value("title", in: text), "a: \"b\"\nnext")
        XCTAssertTrue(text.contains("pubDate: 2026-10-13")); XCTAssertTrue(text.contains("draft: true"))
    }

    func testMixedChineseAndEnglishStatisticsIgnoreMetadata() {
        let stats = WritingStatistics(text: "---\ntitle: not counted\n---\n\n你好 world test")
        XCTAssertEqual(stats.words, 4); XCTAssertEqual(stats.characters, 11); XCTAssertEqual(stats.readingMinutes, 1)
        XCTAssertEqual(WritingStatistics(text: "").readingMinutes, 0)
    }

    func testWorkspaceOnlyListsMarkdownAndSkipsDevelopmentDirectories() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for path in ["posts", "node_modules", ".git", "build"] { try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true) }
        for path in ["posts/hello.md", "posts/other.markdown", "posts/image.png", "node_modules/dependency.md", ".git/hidden.md", "build/output.md"] {
            try "content".write(to: root.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
        let scanned = try WorkspaceScanner.scan(root)
        XCTAssertEqual(scanned.map(\.relativePath), ["posts/hello.md", "posts/other.markdown"])
    }
}
