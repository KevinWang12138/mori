import Foundation

public struct ExternalFileCheck: Sendable {
    public let documentID: UUID
    public let snapshot: DiskSnapshot?
    private let path: String
    private let fingerprint: String

    // ===== 在后台读取磁盘版本，并记录本次读取对应的文档基线 =====
    public init?(document: RecoverableDocument) {
        guard let path = document.path, let fingerprint = document.fingerprint else { return nil }
        documentID = document.id; self.path = path; self.fingerprint = fingerprint
        snapshot = try? DocumentFileService.read(URL(fileURLWithPath: path))
    }

    // ===== 保存、另存或关闭后不应用旧检查结果，避免异步检查回退新版本 =====
    public func stillMatches(_ document: RecoverableDocument) -> Bool {
        document.id == documentID && document.path == path && document.fingerprint == fingerprint
    }
}
