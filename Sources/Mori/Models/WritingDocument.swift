import Foundation
import MoriCore

struct WritingDocument: Identifiable, Equatable {
    var recovery: RecoverableDocument
    var conflict = false
    var saveFailure: String?
    var lastSaved: Date?
    var id: UUID { recovery.id }
    var content: String { recovery.content }
    var url: URL? { recovery.path.map { URL(fileURLWithPath: $0) } }
    var isDirty: Bool { content != recovery.savedContent }
    var title: String { MarkdownAnalysis.title(in: content, fallback: url?.deletingPathExtension().lastPathComponent ?? "未命名文章") }
    var filename: String { url?.lastPathComponent ?? title }
    var revisionKey: String { recovery.path ?? id.uuidString }
}

enum EditorMode: String, Codable, CaseIterable, Identifiable {
    case rich, source, split
    var id: String { rawValue }
    var label: String { switch self { case .rich: return "写作"; case .source: return "源码"; case .split: return "分栏" } }
    var icon: String { switch self { case .rich: return "pencil.line"; case .source: return "chevron.left.forwardslash.chevron.right"; case .split: return "rectangle.split.2x1" } }
}

enum InspectorPanel: String, CaseIterable, Identifiable {
    case outline, blog, history
    var id: String { rawValue }
    var label: String { switch self { case .outline: return "大纲"; case .blog: return "博客"; case .history: return "历史" } }
}
