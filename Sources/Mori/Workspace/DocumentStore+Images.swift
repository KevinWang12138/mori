import AppKit
import UniformTypeIdentifiers

extension DocumentStore {
    func chooseImage() {
        guard let id = activeID else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]; panel.prompt = L10n.text("插入图片")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { importImage(data: try Data(contentsOf: url), name: url.lastPathComponent, documentID: id) }
        catch { errorMessage = L10n.text("图片无法读取。请换一张图片重试。") }
    }

    func importImage(data: Data, name: String, documentID: UUID) {
        guard var document = documents.first(where: { $0.id == documentID }) else { return }
        if document.url == nil {
            notice = L10n.text("先保存文章，图片会存到文章旁边的 assets 文件夹。")
            guard saveAs(id: documentID), let refreshed = documents.first(where: { $0.id == documentID }) else { return }
            document = refreshed
        }
        guard let url = document.url else { return }
        do {
            let path = try ImageImportService.importImage(data: data, name: name, articleURL: url)
            if activeID != documentID { activate(documentID) }
            editor.perform("insertImage", payload: ["src": path, "alt": URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent])
        } catch { errorMessage = L10n.text("图片未能导入。请检查文章文件夹的写入权限，图片需小于 25 MB。") }
    }
}
