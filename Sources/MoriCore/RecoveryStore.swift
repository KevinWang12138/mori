import Foundation

public struct RecoverableDocument: Codable, Identifiable, Equatable {
    public var id: UUID
    public var path: String?
    public var content: String
    public var savedContent: String
    public var fingerprint: String?
    public var usesCRLF: Bool
    public var hasBOM: Bool

    public init(id: UUID = UUID(), path: String? = nil, content: String, savedContent: String = "",
        fingerprint: String? = nil, usesCRLF: Bool = false, hasBOM: Bool = false) {
        self.id = id; self.path = path; self.content = content; self.savedContent = savedContent
        self.fingerprint = fingerprint; self.usesCRLF = usesCRLF; self.hasBOM = hasBOM
    }
}

public struct RecoverySession: Codable {
    public var documents: [RecoverableDocument]
    public var activeID: UUID?
    public var workspacePath: String?

    public init(documents: [RecoverableDocument], activeID: UUID?, workspacePath: String?) {
        self.documents = documents; self.activeID = activeID; self.workspacePath = workspacePath
    }
}

public struct DocumentRevision: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let content: String
    public init(content: String) { id = UUID(); date = Date(); self.content = content }
}

public struct RecoveryStore {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    private var sessionURL: URL { directory.appendingPathComponent("session.json") }

    public func load() throws -> RecoverySession? {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return nil }
        return try JSONDecoder().decode(RecoverySession.self, from: Data(contentsOf: sessionURL))
    }

    public func save(_ session: RecoverySession) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(session)
        try data.write(to: sessionURL, options: .atomic)
    }

    // ===== 留存损坏的恢复档案，后续写入不会覆盖唯一副本 =====
    public func quarantine() throws {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return }
        let backup = directory.appendingPathComponent("session-recovery-\(UUID().uuidString).json")
        try FileManager.default.moveItem(at: sessionURL, to: backup)
    }

    public func revisions(for key: String) throws -> [DocumentRevision] {
        let url = revisionURL(key)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([DocumentRevision].self, from: Data(contentsOf: url))
    }

    public func addRevision(_ content: String, for key: String) throws {
        var history = try revisions(for: key)
        guard history.first?.content != content else { return }
        history.insert(DocumentRevision(content: content), at: 0)
        history = Array(history.prefix(50))
        let url = revisionURL(key)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(history).write(to: url, options: .atomic)
    }

    private func revisionURL(_ key: String) -> URL {
        directory.appendingPathComponent("Versions").appendingPathComponent(DocumentFileService.fingerprint(Data(key.utf8)) + ".json")
    }
}
