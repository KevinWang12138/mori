import AppKit
import WebKit

enum ArticleExportFormat { case html, pdf, print }

@MainActor
final class ArticleExportService: NSObject, WKNavigationDelegate {
    static let shared = ArticleExportService()
    private var printView: WKWebView?
    private var outputURL: URL?
    private var finish: ((Bool) -> Void)?
    private var showPrintPanel = false

    // ===== 把本地图片与公式字体嵌入 HTML，导出文件可独立移动 =====
    func standaloneHTML(_ html: String, assets: AssetSchemeHandler) -> String {
        var output = html
        if let expression = try? NSRegularExpression(pattern: "mori-asset://local[^\"'<>\\s]+") {
            let matches = expression.matches(in: output, range: NSRange(output.startIndex..., in: output))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: output) else { continue }
                let raw = String(output[range]).replacingOccurrences(of: "&amp;", with: "&")
                guard let source = URL(string: raw),
                    let url = assets.permittedURL(URL(fileURLWithPath: source.path)),
                    let data = try? Data(contentsOf: url), data.count < 25 * 1024 * 1024 else { output.replaceSubrange(range, with: ""); continue }
                let mime = url.pathExtension == "svg" ? "image/svg+xml" : "image/" + (url.pathExtension == "jpg" ? "jpeg" : url.pathExtension)
                output.replaceSubrange(range, with: "data:\(mime);base64,\(data.base64EncodedString())")
            }
        }
        if let expression = try? NSRegularExpression(pattern: "(?:file://[^\"')]*?/)?fonts/[A-Za-z0-9_-]+\\.(?:woff2|woff|ttf)") {
            let matches = expression.matches(in: output, range: NSRange(output.startIndex..., in: output))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: output) else { continue }
                let raw = String(output[range]); let filename = URL(fileURLWithPath: raw).lastPathComponent
                let url = AppPaths.web.appendingPathComponent("fonts/" + filename)
                guard let data = try? Data(contentsOf: url) else { continue }
                let mime = "font/" + url.pathExtension
                output.replaceSubrange(range, with: "data:\(mime);base64,\(data.base64EncodedString())")
            }
        }
        return output
    }

    func printHTML(_ html: String, destination: URL?, showPanel: Bool, completion: @escaping (Bool) -> Void) {
        guard printView == nil else { completion(false); return }
        outputURL = destination; finish = completion; showPrintPanel = showPanel
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 720, height: 1000), configuration: configuration)
        view.navigationDelegate = self; printView = view
        view.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.callAsyncJavaScript("await document.fonts.ready; await Promise.all([...document.images].map(image => image.complete ? Promise.resolve() : new Promise(resolve => { image.onload = resolve; image.onerror = resolve; setTimeout(resolve, 6000); }))); return true;", arguments: [:], in: nil, in: .page) { [weak self] _ in
            self?.runPrintOperation()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { complete(false) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { complete(false) }

    private func runPrintOperation() {
        guard let printView else { complete(false); return }
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 595.28, height: 841.89)
        info.topMargin = 50; info.bottomMargin = 50; info.leftMargin = 44; info.rightMargin = 44
        info.horizontalPagination = .fit; info.verticalPagination = .automatic
        info.isHorizontallyCentered = false; info.isVerticallyCentered = false
        if let outputURL { info.jobDisposition = .save; info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = outputURL }
        let operation = printView.printOperation(with: info)
        operation.showsPrintPanel = showPrintPanel; operation.showsProgressPanel = false
        let success = operation.run()
        complete(success)
    }

    private func complete(_ success: Bool) {
        let callback = finish; finish = nil; printView?.navigationDelegate = nil; printView = nil; outputURL = nil
        callback?(success)
    }
}
