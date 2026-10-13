import AppKit
import UniformTypeIdentifiers
import MoriCore

extension DocumentStore {
    func openPanel() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.prompt = "打开文章"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { open(url) }
    }

    func open(_ url: URL) {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        if let document = documents.first(where: { $0.url?.standardizedFileURL.resolvingSymlinksInPath() == canonical }) { activate(document.id); return }
        do {
            let snapshot = try DocumentFileService.read(canonical)
            let recovery = RecoverableDocument(path: canonical.path, content: snapshot.content, savedContent: snapshot.content,
                fingerprint: snapshot.fingerprint, usesCRLF: snapshot.usesCRLF, hasBOM: snapshot.hasBOM)
            let document = WritingDocument(recovery: recovery)
            documents.append(document); activate(document.id)
            NSDocumentController.shared.noteNewRecentDocumentURL(canonical)
        } catch { reportFileError(error, fallback: "文章没有打开成功。请检查文件位置与读取权限。") }
    }

    func chooseWorkspace() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.prompt = "打开博客文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        workspaceURL = url; refreshWorkspace(); scheduleRecovery(); showSidebar = true
    }

    func saveActive(asNewFile: Bool = false) {
        let id = activeID
        editor.flush { [weak self] in
            guard let self, let id else { return }
            if asNewFile { _ = self.saveAs(id: id) } else { self.save(id: id) }
        }
    }

    // ===== 保存磁盘文件与版本，冲突时保留内存稿件并停止自动保存 =====
    func save(id: UUID, automatic: Bool = false) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        let document = documents[index]
        guard let url = document.url else { if !automatic { _ = saveAs(id: id) }; return }
        guard !document.conflict else { if !automatic { notice = "请先处理外部修改，或使用“另存为”保留当前稿件。" }; return }
        guard document.isDirty else { return }
        let captureVersion = !automatic || Date().timeIntervalSince(revisionDates[id] ?? .distantPast) > 60
        if captureVersion && !document.recovery.savedContent.isEmpty {
            do { try recovery.addRevision(document.recovery.savedContent, for: document.revisionKey) }
            catch { notice = "文章会继续保存，本机历史版本暂时无法写入。" }
        }
        do {
            let fingerprint = try DocumentFileService.write(document.content, to: url, expectedFingerprint: document.recovery.fingerprint,
                usesCRLF: document.recovery.usesCRLF, hasBOM: document.recovery.hasBOM)
            documents[index].recovery.fingerprint = fingerprint
            documents[index].recovery.savedContent = document.content
            documents[index].lastSaved = Date(); documents[index].saveFailure = nil
            if captureVersion {
                do { try recovery.addRevision(document.content, for: document.revisionKey); revisionDates[id] = Date() }
                catch { notice = "文章已保存，本机历史版本暂时无法写入。" }
            }
            flushRecovery(); if id == activeID { loadRevisions() }
        } catch {
            if (error as? DocumentFileError) == .conflict { documents[index].conflict = true }
            documents[index].saveFailure = "保存未完成，稿件已保留。"
            if !automatic { reportFileError(error, fallback: "文章没有保存成功。请检查目标文件夹权限，或另存一份。") }
            flushRecovery()
        }
    }

    @discardableResult
    func saveAs(id: UUID) -> Bool {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return false }
        let document = documents[index]
        let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = document.url?.lastPathComponent ?? safeFilename(document.title) + ".md"
        panel.directoryURL = document.url?.deletingLastPathComponent() ?? workspaceURL
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return false }
        let url = destination.standardizedFileURL.resolvingSymlinksInPath()
        guard !documents.contains(where: { $0.id != id && $0.url == url }) else {
            errorMessage = "这份文件已经在其他标签中打开。请换一个文件名。"; return false
        }
        do {
            let fingerprint = try DocumentFileService.write(document.content, to: url, expectedFingerprint: nil,
                usesCRLF: document.recovery.usesCRLF, hasBOM: document.recovery.hasBOM, allowOverwrite: true)
            documents[index].recovery.path = url.path; documents[index].recovery.fingerprint = fingerprint
            documents[index].recovery.savedContent = document.content; documents[index].conflict = false
            documents[index].saveFailure = nil; documents[index].lastSaved = Date()
            do { try recovery.addRevision(document.content, for: url.path) }
            catch { notice = "文章已保存，本机历史版本暂时无法写入。" }
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            refreshWorkspace(); flushRecovery(); loadRevisions(); editor.resetDocument()
            return true
        } catch { reportFileError(error, fallback: "文章没有保存成功。请检查目标位置的写入权限。"); return false }
    }

    func close(_ id: UUID) {
        editor.flush { [weak self] in self?.finishClose(id) }
    }

    private func finishClose(_ id: UUID) {
        guard let document = documents.first(where: { $0.id == id }) else { return }
        if document.isDirty {
            let alert = NSAlert(); alert.messageText = "保存“\(document.title)”的修改"
            alert.informativeText = "保存到 Markdown 文件后即可关闭。选择放弃会删除此标签的未保存稿件。"
            alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消"); alert.addButton(withTitle: "放弃修改")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                if document.url == nil || document.conflict { guard saveAs(id: id) else { return } }
                else { save(id: id); guard documents.first(where: { $0.id == id })?.isDirty == false else { return } }
            case .alertThirdButtonReturn: break
            default: return
            }
        }
        autosaveTasks[id]?.cancel(); autosaveTasks.removeValue(forKey: id)
        let originalIndex = documents.firstIndex(where: { $0.id == id }) ?? 0
        documents.removeAll { $0.id == id }
        editor.perform("dispose", payload: ["id": id.uuidString])
        if activeID == id { activeID = documents.isEmpty ? nil : documents[min(originalIndex, documents.count - 1)].id }
        loadRevisions(); flushRecovery()
    }

    func reloadExternalFile() {
        guard let index = documents.firstIndex(where: { $0.id == activeID }), let url = documents[index].url else { return }
        do {
            try recovery.addRevision(documents[index].content, for: documents[index].revisionKey)
            let snapshot = try DocumentFileService.read(url)
            documents[index].recovery.content = snapshot.content; documents[index].recovery.savedContent = snapshot.content
            documents[index].recovery.fingerprint = snapshot.fingerprint; documents[index].recovery.usesCRLF = snapshot.usesCRLF
            documents[index].recovery.hasBOM = snapshot.hasBOM; documents[index].conflict = false
            documents[index].saveFailure = nil; editor.resetDocument(); loadRevisions(); flushRecovery()
            notice = "已载入磁盘版本，原稿件保存在历史中。"
        } catch { reportFileError(error, fallback: "磁盘版本无法载入，当前稿件已保留。") }
    }

    func checkExternalChanges() {
        for index in documents.indices {
            guard let url = documents[index].url, let expected = documents[index].recovery.fingerprint,
                !documents[index].conflict else { continue }
            guard let snapshot = try? DocumentFileService.read(url) else {
                documents[index].conflict = true; continue
            }
            guard snapshot.fingerprint != expected else { continue }
            if documents[index].isDirty { documents[index].conflict = true; autosaveTasks[documents[index].id]?.cancel() }
            else {
                documents[index].recovery.content = snapshot.content; documents[index].recovery.savedContent = snapshot.content
                documents[index].recovery.fingerprint = snapshot.fingerprint
                documents[index].recovery.usesCRLF = snapshot.usesCRLF; documents[index].recovery.hasBOM = snapshot.hasBOM
            }
        }
    }

    func reportFileError(_ error: Error, fallback: String) {
        errorMessage = (error as? DocumentFileError)?.errorDescription ?? fallback
    }

    private func safeFilename(_ title: String) -> String {
        let cleaned = title.replacingOccurrences(of: "[/\\\\:*?\"<>|]", with: "-", options: .regularExpression)
        return String(cleaned.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
