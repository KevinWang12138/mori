import XCTest
@testable import MoriCore

final class DocumentSafetyTests: XCTestCase {
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("MoriTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testExternalChangeNeverGetsOverwritten() throws {
        let file = directory.appendingPathComponent("article.md")
        let first = try DocumentFileService.write("original", to: file, expectedFingerprint: nil)
        try "external content".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try DocumentFileService.write("my draft", to: file, expectedFingerprint: first)) { error in
            XCTAssertEqual(error as? DocumentFileError, .conflict)
        }
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "external content")
    }

    func testNewSaveDoesNotOverwriteExistingFileWithoutAuthorization() throws {
        let file = directory.appendingPathComponent("article.md")
        try "original".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try DocumentFileService.write("new", to: file, expectedFingerprint: nil))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "original")
    }

    func testExpectedVersionAndBOMAndLineEndingsRoundTrip() throws {
        let file = directory.appendingPathComponent("article.md")
        let first = try DocumentFileService.write("# 你好\n\n正文\n", to: file, expectedFingerprint: nil, usesCRLF: true, hasBOM: true)
        let read = try DocumentFileService.read(file)
        XCTAssertEqual(read.content, "# 你好\n\n正文\n")
        XCTAssertTrue(read.usesCRLF); XCTAssertTrue(read.hasBOM); XCTAssertEqual(read.fingerprint, first)
        _ = try DocumentFileService.write(read.content + "下一段\n", to: file, expectedFingerprint: first, usesCRLF: read.usesCRLF, hasBOM: read.hasBOM)
        let bytes = try Data(contentsOf: file)
        XCTAssertTrue(bytes.starts(with: [0xEF, 0xBB, 0xBF]))
        XCTAssertEqual(String(data: Data(bytes.dropFirst(3)), encoding: .utf8), "# 你好\r\n\r\n正文\r\n下一段\r\n")
    }

    func testMissingOriginalFileIsAConflict() throws {
        let file = directory.appendingPathComponent("article.md")
        let hash = try DocumentFileService.write("draft", to: file, expectedFingerprint: nil)
        try FileManager.default.removeItem(at: file)
        XCTAssertThrowsError(try DocumentFileService.write("changed", to: file, expectedFingerprint: hash))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testInvalidEncodingAndLargeFilesAreRejected() throws {
        let file = directory.appendingPathComponent("binary.md")
        try Data([0xFF, 0xF0, 0xFE]).write(to: file)
        XCTAssertThrowsError(try DocumentFileService.read(file)) { XCTAssertEqual($0 as? DocumentFileError, .notUTF8) }
        try Data(repeating: 32, count: 20 * 1024 * 1024 + 1).write(to: file)
        XCTAssertThrowsError(try DocumentFileService.read(file)) { XCTAssertEqual($0 as? DocumentFileError, .tooLarge) }
    }

    func testRecoveryRestoresUnsavedDraftsAndDirtyFiles() throws {
        let store = RecoveryStore(directory: directory)
        let draft = RecoverableDocument(content: "unsaved blog")
        let dirty = RecoverableDocument(path: "/example/blog.md", content: "edited", savedContent: "old", fingerprint: "disk-version")
        try store.save(RecoverySession(documents: [draft, dirty], activeID: dirty.id, workspacePath: "/example"))
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.documents, [draft, dirty]); XCTAssertEqual(loaded.activeID, dirty.id); XCTAssertEqual(loaded.workspacePath, "/example")
    }

    func testCorruptRecoveryIsPreservedBeforeCreatingNewSession() throws {
        let store = RecoveryStore(directory: directory)
        let bad = Data("broken data".utf8)
        try bad.write(to: directory.appendingPathComponent("session.json"))
        XCTAssertThrowsError(try store.load())
        try store.quarantine()
        try store.save(RecoverySession(documents: [], activeID: nil, workspacePath: nil))
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let backup = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("session-recovery-") })
        XCTAssertEqual(try Data(contentsOf: backup), bad)
    }

    func testHistoryIsDeduplicatedAndRetainsLastFiftyVersions() throws {
        let store = RecoveryStore(directory: directory)
        for index in 0..<55 { try store.addRevision("version \(index)", for: "article") }
        try store.addRevision("version 54", for: "article")
        let history = try store.revisions(for: "article")
        XCTAssertEqual(history.count, 50); XCTAssertEqual(history.first?.content, "version 54"); XCTAssertEqual(history.last?.content, "version 5")
    }
}
