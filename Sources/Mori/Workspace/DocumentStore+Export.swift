import AppKit
import UniformTypeIdentifiers

extension DocumentStore {
    func exportArticle(_ format: ArticleExportFormat) {
        guard let document = activeDocument else { return }
        var destination: URL?
        if format != .print {
            let panel = NSSavePanel(); panel.canCreateDirectories = true
            panel.allowedContentTypes = [format == .html ? .html : .pdf]
            panel.nameFieldStringValue = (document.url?.deletingPathExtension().lastPathComponent ?? document.title) + (format == .html ? ".html" : ".pdf")
            guard panel.runModal() == .OK, let url = panel.url else { return }
            destination = url
        }
        let capturedDestination = destination
        editor.exportHTML { [weak self] html in
            guard let self, let html else { self?.errorMessage = "导出暂时无法完成。请等编辑器加载后重试。"; return }
            let standalone = ArticleExportService.shared.standaloneHTML(html, assets: self.editor.assets)
            if format == .html, let capturedDestination {
                do { try standalone.write(to: capturedDestination, atomically: true, encoding: .utf8); self.notice = "HTML 已导出，包含本地图片与公式字体。" }
                catch { self.errorMessage = "HTML 未能写入。请检查目标文件夹权限。" }
            } else {
                ArticleExportService.shared.printHTML(standalone, destination: capturedDestination, showPanel: format == .print) { [weak self] success in
                    if success { self?.notice = format == .print ? "打印操作已完成。" : "PDF 已导出。" }
                    else if format != .print { self?.errorMessage = "PDF 导出未完成。请检查目标文件夹权限。" }
                }
            }
        }
    }

    func copyMarkdown() {
        editor.flush { [weak self] in
            guard let content = self?.activeDocument?.content else { return }
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(content, forType: .string)
            self?.notice = "Markdown 已复制。"
        }
    }

    func copyHTML() {
        editor.exportHTML { [weak self] html in
            guard let self, let html else { return }
            let standalone = ArticleExportService.shared.standaloneHTML(html, assets: self.editor.assets)
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(standalone, forType: .html)
            NSPasteboard.general.setString(standalone, forType: .string); self.notice = "HTML 已复制。"
        }
    }
}
