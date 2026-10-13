import Foundation
import MoriCore

extension DocumentStore {
    func restoreSession() {
        do {
            guard let session = try recovery.load() else { return }
            documents = session.documents.map { item in
                var document = WritingDocument(recovery: item)
                if let url = document.url, let disk = try? DocumentFileService.read(url) {
                    if !document.isDirty {
                        document.recovery.content = disk.content; document.recovery.savedContent = disk.content
                        document.recovery.fingerprint = disk.fingerprint; document.recovery.usesCRLF = disk.usesCRLF
                        document.recovery.hasBOM = disk.hasBOM
                    } else if disk.fingerprint != item.fingerprint { document.conflict = true }
                } else if item.path != nil { document.conflict = true }
                return document
            }
            activeID = documents.contains(where: { $0.id == session.activeID }) ? session.activeID : documents.first?.id
            workspaceURL = session.workspacePath.map { URL(fileURLWithPath: $0) }
            refreshWorkspace(); loadRevisions()
        } catch {
            do { try recovery.quarantine() }
            catch { recoveryBlocked = true; errorMessage = "恢复档案暂时无法读取，也无法备份。请检查 Mori 资料目录的权限。"; return }
            errorMessage = "上一份恢复档案未能读取，原档案已单独保留在 Mori 资料目录。"
        }
    }

    func scheduleRecovery() {
        recoveryTask?.cancel()
        recoveryTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.flushRecovery()
        }
    }

    @discardableResult
    func flushRecovery() -> Bool {
        recoveryTask?.cancel()
        guard !recoveryBlocked else { return false }
        do {
            try recovery.save(RecoverySession(documents: documents.map(\.recovery), activeID: activeID, workspacePath: workspaceURL?.path))
            return true
        } catch { errorMessage = "草稿恢复档案没有写入成功。请先将文章保存到文件，并检查磁盘可用空间。"; return false }
    }

    func prepareToQuit(completion: @escaping (Bool) -> Void) {
        editor.flush { [weak self] in
            guard let self else { completion(true); return }
            for document in self.documents where document.isDirty && document.url != nil && !document.conflict {
                self.save(id: document.id, automatic: true)
            }
            completion(self.flushRecovery())
        }
    }
}
