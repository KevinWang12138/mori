import Foundation
import WebKit
import UniformTypeIdentifiers

final class AssetSchemeHandler: NSObject, WKURLSchemeHandler {
    var roots: [URL] = []

    // ===== 只提供用户打开的文章范围内的图片，拒绝越界路径与符号链接 =====
    func permittedURL(_ url: URL) -> URL? {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        guard roots.contains(where: { root in
            let directory = root.standardizedFileURL.resolvingSymlinksInPath().path
            return canonical.path.hasPrefix(directory + "/")
        }) else { return nil }
        let allowed = Set(["png", "jpg", "jpeg", "gif", "webp", "heic", "tif", "tiff", "svg"])
        return allowed.contains(canonical.pathExtension.lowercased()) ? canonical : nil
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requested = urlSchemeTask.request.url,
            let url = permittedURL(URL(fileURLWithPath: requested.path)),
            let data = try? Data(contentsOf: url), data.count <= 25 * 1024 * 1024 else {
            urlSchemeTask.didFailWithError(CocoaError(.fileReadNoPermission)); return
        }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let response = URLResponse(url: requested, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil)
        urlSchemeTask.didReceive(response); urlSchemeTask.didReceive(data); urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
