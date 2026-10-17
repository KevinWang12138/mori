import Foundation
import MoriCore

extension DocumentStore {
    // ===== 定时磁盘检查在后台串行执行，主线程只应用仍匹配的结果 =====
    func checkExternalChanges() {
        guard diskCheckTask == nil else { return }
        let captured = documents.filter { $0.url != nil && !$0.conflict }.map(\.recovery)
        guard !captured.isEmpty else { return }
        diskCheckTask = Task { [weak self] in
            let worker = Task.detached(priority: .utility) {
                var checks: [ExternalFileCheck] = []
                for document in captured {
                    if Task.isCancelled { break }
                    if let check = ExternalFileCheck(document: document) { checks.append(check) }
                }
                return checks
            }
            let checks = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard let self else { return }
            self.diskCheckTask = nil
            guard !Task.isCancelled else { return }
            self.applyExternalChecks(checks)
        }
    }

    private func applyExternalChecks(_ checks: [ExternalFileCheck]) {
        var changed = false
        for check in checks {
            guard let index = documents.firstIndex(where: { $0.id == check.documentID }),
                !documents[index].conflict, check.stillMatches(documents[index].recovery),
                check.snapshot?.fingerprint != documents[index].recovery.fingerprint else { continue }
            changed = true
            if let snapshot = check.snapshot, !documents[index].isDirty {
                documents[index].recovery.content = snapshot.content; documents[index].recovery.savedContent = snapshot.content
                documents[index].recovery.fingerprint = snapshot.fingerprint
                documents[index].recovery.usesCRLF = snapshot.usesCRLF; documents[index].recovery.hasBOM = snapshot.hasBOM
                if searchContent, let path = documents[index].recovery.path { searchCache[path] = snapshot.content }
            } else {
                documents[index].conflict = true; autosaveTasks[check.documentID]?.cancel()
            }
        }
        if changed { scheduleRecovery() }
    }

    // ===== 刷新与切换文件夹取消旧扫描，目录遍历不阻塞正在输入的文章 =====
    func refreshWorkspace() {
        workspaceTask?.cancel(); searchTask?.cancel()
        guard let root = workspaceURL else { articles = []; searchCache = [:]; return }
        workspaceTask = Task { [weak self] in
            let worker = Task.detached(priority: .utility) { try WorkspaceScanner.scan(root) }
            do {
                let articles = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled, let self, self.workspaceURL == root else { return }
                self.articles = articles; self.indexSearchContent()
            } catch {
                guard !Task.isCancelled, let self, self.workspaceURL == root else { return }
                self.errorMessage = L10n.text("文章文件夹暂时无法读取。请重新选择文件夹。")
            }
        }
    }

    // ===== 正文索引可以取消，先检查体积再读取，关闭搜索时释放旧缓存 =====
    func indexSearchContent() {
        searchTask?.cancel()
        guard searchContent else { searchCache = [:]; return }
        let captured = articles; let root = workspaceURL
        searchTask = Task { [weak self] in
            let worker = Task.detached(priority: .utility) { WorkspaceScanner.searchContents(captured) }
            let contents = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard !Task.isCancelled, let self, self.searchContent, self.workspaceURL == root else { return }
            self.objectWillChange.send(); self.searchCache = contents
        }
    }
}
