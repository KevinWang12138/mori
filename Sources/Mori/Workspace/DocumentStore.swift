import AppKit
import Combine
import MoriCore

@MainActor
final class DocumentStore: ObservableObject {
    @Published var documents: [WritingDocument] = []
    @Published var activeID: UUID?
    @Published var workspaceURL: URL?
    @Published var articles: [WorkspaceArticle] = []
    @Published var query = ""
    @Published var searchContent = false
    @Published var sortByRecent = false
    @Published var mode: EditorMode = .rich
    @Published var inspector: InspectorPanel = .outline
    @Published var showSidebar = true
    @Published var showInspector = false
    @Published var focusMode = false
    @Published var typewriterMode = false
    @Published var showAppearance = false
    @Published var showNewArticle = false
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var revisions: [DocumentRevision] = []
    let recovery = RecoveryStore(directory: AppPaths.support)
    let editor = EditorBridge()
    let preferences: PreferencesStore
    var autosaveTasks: [UUID: Task<Void, Never>] = [:]
    var recoveryTask: Task<Void, Never>?
    var searchTask: Task<Void, Never>?
    var workspaceTask: Task<Void, Never>?
    var diskCheckTask: Task<Void, Never>?
    var revisionDates: [UUID: Date] = [:]
    var recoveryBlocked = false
    private var diskTimer: Timer?
    var searchCache: [String: String] = [:]
    private var statisticsContent: String?
    private var cachedStatistics = WritingStatistics(text: "")
    private var outlineContent: String?
    private var cachedHeadings: [MarkdownHeading] = []

    var activeDocument: WritingDocument? { documents.first { $0.id == activeID } }
    var statistics: WritingStatistics {
        let content = activeDocument?.content ?? ""
        if statisticsContent != content { cachedStatistics = WritingStatistics(text: content); statisticsContent = content }
        return cachedStatistics
    }
    var headings: [MarkdownHeading] {
        let content = activeDocument?.content ?? ""
        if outlineContent != content { cachedHeadings = MarkdownAnalysis.headings(in: content); outlineContent = content }
        return cachedHeadings
    }
    var visibleArticles: [WorkspaceArticle] {
        let openContents = Dictionary(documents.compactMap { document in
            document.url.map { ($0.path, document.content) }
        }, uniquingKeysWith: { _, latest in latest })
        let filtered = articles.filter { article in
            query.isEmpty || article.relativePath.localizedCaseInsensitiveContains(query)
                || (searchContent && (openContents[article.id] ?? searchCache[article.id] ?? "").localizedCaseInsensitiveContains(query))
        }
        return sortByRecent ? filtered.sorted { $0.modified > $1.modified } : filtered
    }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        restoreSession()
        if documents.isEmpty { newWelcome() }
        editor.onChange = { [weak self] id, text in self?.update(id: id, content: text) }
        editor.onMessage = { [weak self] message in self?.handleEditorMessage(message) }
        diskTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkExternalChanges() }
        }
    }

    deinit {
        diskTimer?.invalidate(); diskCheckTask?.cancel(); workspaceTask?.cancel(); searchTask?.cancel(); recoveryTask?.cancel()
        for task in autosaveTasks.values { task.cancel() }
    }

    func activate(_ id: UUID) {
        activeID = id; loadRevisions(); scheduleRecovery()
    }

    // ===== 在明确的文档 ID 上更新内容，避免切换标签时串稿 =====
    func update(id: UUID, content: String) {
        guard let index = documents.firstIndex(where: { $0.id == id }), documents[index].content != content else { return }
        documents[index].recovery.content = content
        documents[index].saveFailure = nil
        scheduleRecovery()
        autosaveTasks[id]?.cancel()
        guard preferences.value.autosave, documents[index].url != nil, !documents[index].conflict else { return }
        autosaveTasks[id] = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.save(id: id, automatic: true)
        }
    }

    func newDocument(template: BlogTemplate = .blank, title: String = L10n.text("未命名文章")) {
        let date = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let content = FrontMatter.template(style: template, title: title, date: String(date))
        let document = WritingDocument(recovery: RecoverableDocument(content: content), startsInBody: true)
        documents.append(document); activate(document.id); notice = L10n.text("草稿会自动保留在本机。")
    }

    func newWelcome() {
        let document = WritingDocument(recovery: RecoverableDocument(content: WelcomeArticle.content))
        documents.append(document); activeID = document.id; scheduleRecovery()
    }

    func loadRevisions() {
        guard let document = activeDocument else { revisions = []; return }
        do { revisions = try recovery.revisions(for: document.revisionKey) }
        catch { revisions = []; errorMessage = L10n.text("历史版本暂时无法读取，当前文章不受影响。") }
    }

    func restoreRevision(_ revision: DocumentRevision) {
        guard let document = activeDocument else { return }
        do { try recovery.addRevision(document.content, for: document.revisionKey) }
        catch { errorMessage = L10n.text("无法备份当前稿件，已停止恢复历史版本。"); return }
        update(id: document.id, content: revision.content); loadRevisions()
        editor.resetDocument(); notice = L10n.text("已恢复历史稿件，恢复前的内容也已保留。")
    }

    func revealCurrentFile() {
        if let url = activeDocument?.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    func handleEditorMessage(_ message: EditorMessage) {
        switch message {
        case .openURL(let value):
            guard let url = URL(string: value), ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return }
            NSWorkspace.shared.open(url)
        case .asset(let id, let data, let name): importImage(data: data, name: name, documentID: id)
        case .openArticle(let path):
            guard let directory = activeDocument?.url?.deletingLastPathComponent(), !path.contains(":") else { return }
            let target = directory.appendingPathComponent(path.components(separatedBy: "#")[0].removingPercentEncoding ?? path).standardizedFileURL.resolvingSymlinksInPath()
            let root = (workspaceURL ?? directory).standardizedFileURL.resolvingSymlinksInPath()
            guard target.path.hasPrefix(root.path + "/") else { return }
            open(target)
        case .action(let name):
            if name == "focus" { focusMode.toggle() }
            else if name == "typewriter" { typewriterMode.toggle() }
        case .unsupported: mode = .source; notice = L10n.text("这篇文章含扩展语法，已使用源码模式保留完整内容。")
        case .error: errorMessage = L10n.text("编辑器暂时无法处理这项操作。你的稿件已保留，请切到源码模式继续。")
        }
    }
}
