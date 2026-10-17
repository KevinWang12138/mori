import Foundation
import CryptoKit

public struct DiskSnapshot: Equatable, Sendable {
    public let content: String
    public let fingerprint: String
    public let usesCRLF: Bool
    public let hasBOM: Bool
}

public enum DocumentFileError: Error, LocalizedError, Equatable {
    case notUTF8, tooLarge, conflict, inaccessible
    public var errorDescription: String? {
        switch self {
        case .notUTF8: return "这份文件不是 UTF-8 文本。请先转换编码再打开。"
        case .tooLarge: return "文件超过 20 MB。请拆成较小的文章后再打开。"
        case .conflict: return "文件已被其他应用修改或移动。你的稿件仍在 Mori 中，另存一份可以保留两边的内容。"
        case .inaccessible: return "无法访问这份文件。请检查文件位置与读写权限。"
        }
    }
}

public enum DocumentFileService {
    public static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func read(_ url: URL) throws -> DiskSnapshot {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= 20 * 1024 * 1024 else { throw DocumentFileError.tooLarge }
        let data = try Data(contentsOf: url)
        let hasBOM = data.starts(with: [0xEF, 0xBB, 0xBF])
        let payload = hasBOM ? Data(data.dropFirst(3)) : data
        guard let content = String(data: payload, encoding: .utf8) else { throw DocumentFileError.notUTF8 }
        return DiskSnapshot(content: content.replacingOccurrences(of: "\r\n", with: "\n"), fingerprint: fingerprint(data),
            usesCRLF: content.contains("\r\n"), hasBOM: hasBOM)
    }

    // ===== 协调原子写入并检查外部修改，避免自动保存覆盖其他应用内容 =====
    @discardableResult
    public static func write(_ content: String, to url: URL, expectedFingerprint: String?,
        usesCRLF: Bool = false, hasBOM: Bool = false, allowOverwrite: Bool = false) throws -> String {
        var failure: Error?
        var coordinationError: NSError?
        var result = ""
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { destination in
            do {
                // ===== 1.在受协调的写入范围内核对磁盘版本 =====
                if let expected = expectedFingerprint, !allowOverwrite {
                    guard let existing = try? Data(contentsOf: destination), fingerprint(existing) == expected else { throw DocumentFileError.conflict }
                } else if expectedFingerprint == nil && !allowOverwrite && FileManager.default.fileExists(atPath: destination.path) {
                    throw DocumentFileError.conflict
                }
                // ===== 2.恢复文件原有换行与 BOM 后原子替换 =====
                let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
                let output = usesCRLF ? normalized.replacingOccurrences(of: "\n", with: "\r\n") : normalized
                var data = hasBOM ? Data([0xEF, 0xBB, 0xBF]) : Data()
                data.append(Data(output.utf8))
                try data.write(to: destination, options: .atomic)
                result = fingerprint(data)
            } catch { failure = error }
        }
        if let error = failure ?? coordinationError { throw error }
        return result
    }
}
