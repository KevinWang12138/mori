import Foundation
import MoriCore

struct WritingDocument: Identifiable, Equatable {
    var recovery: RecoverableDocument {
        didSet {
            if recovery.content != oldValue.content { contentTitle = MarkdownAnalysis.title(in: recovery.content, fallback: "") }
        }
    }
    var startsInBody = false
    var conflict = false
    var saveFailure: String?
    var lastSaved: Date?
    private var contentTitle: String
    var id: UUID { recovery.id }
    var content: String { recovery.content }
    var url: URL? { recovery.path.map { URL(fileURLWithPath: $0) } }
    var isDirty: Bool { content != recovery.savedContent }
    var title: String { contentTitle.isEmpty ? (url?.deletingPathExtension().lastPathComponent ?? L10n.text("未命名文章")) : contentTitle }
    var filename: String { url?.lastPathComponent ?? title }
    var revisionKey: String { recovery.path ?? id.uuidString }

    init(recovery: RecoverableDocument, startsInBody: Bool = false) {
        self.recovery = recovery; self.startsInBody = startsInBody
        contentTitle = MarkdownAnalysis.title(in: recovery.content, fallback: "")
    }
}

enum EditorMode: String, Codable, CaseIterable, Identifiable {
    case rich, source, split
    var id: String { rawValue }
    var label: String { switch self { case .rich: return L10n.text("写作"); case .source: return L10n.text("源码"); case .split: return L10n.text("分栏") } }
    var icon: String { switch self { case .rich: return "pencil.line"; case .source: return "chevron.left.forwardslash.chevron.right"; case .split: return "rectangle.split.2x1" } }
}

enum InspectorPanel: String, CaseIterable, Identifiable {
    case outline, blog, history
    var id: String { rawValue }
    var label: String { switch self { case .outline: return L10n.text("大纲"); case .blog: return L10n.text("博客"); case .history: return L10n.text("历史") } }
}
