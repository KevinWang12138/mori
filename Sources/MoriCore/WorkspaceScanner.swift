import Foundation

public struct WorkspaceArticle: Identifiable, Equatable {
    public var id: String { url.path }
    public let url: URL
    public let relativePath: String
    public let modified: Date
}

public enum WorkspaceScanner {
    public static let ignoredFolders: Set<String> = ["node_modules", "vendor", "dist", "build", "target", "Pods", "DerivedData"]
    public static let extensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    public static func scan(_ root: URL) throws -> [WorkspaceArticle] {
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        guard let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else { throw DocumentFileError.inaccessible }
        var items: [WorkspaceArticle] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
            if values.isSymbolicLink == true || (values.isDirectory == true && ignoredFolders.contains(url.lastPathComponent)) {
                enumerator.skipDescendants(); continue
            }
            guard values.isRegularFile == true, extensions.contains(url.pathExtension.lowercased()) else { continue }
            let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
            let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
            let relative = canonical.path.hasPrefix(prefix) ? String(canonical.path.dropFirst(prefix.count)) : canonical.lastPathComponent
            items.append(WorkspaceArticle(url: canonical, relativePath: relative, modified: values.contentModificationDate ?? .distantPast))
        }
        return items.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }
}
