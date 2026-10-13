import AppKit
import WebKit
import Combine

enum EditorMessage {
    case openURL(String), openArticle(String), asset(UUID, Data, String), action(String), unsupported, error
}

private struct WebEditorSettings: Encodable {
    var language: String
    var theme: String
    var surface: String
    var text: String
    var muted: String
    var accent: String
    var font: String
    var fontSize: Double
    var lineHeight: Double
    var pageWidth: Double
    var paperOpacity: Double
    var spellcheck: Bool
    var showLineNumbers: Bool
    var focusMode: Bool
    var typewriterMode: Bool
    var customCSS: String
}

private struct WebDocumentPayload: Encodable {
    var id: String
    var startsInBody: Bool
    var markdown: String
    var directory: String
    var mode: String
    var settings: WebEditorSettings
}

@MainActor
final class EditorBridge: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    private(set) var ready = false
    weak var webView: WKWebView?
    let assets = AssetSchemeHandler()
    var onChange: ((UUID, String) -> Void)?
    var onMessage: ((EditorMessage) -> Void)?
    private var pending: WebDocumentPayload?
    private var lastID: String?
    private var lastMarkdown: String?
    private var lastSettings: String?
    private var queued: [(String, [String: Any])] = []

    func makeWebView() -> WKWebView {
        ready = false; lastID = nil; lastMarkdown = nil; lastSettings = nil
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: "mori")
        configuration.setURLSchemeHandler(assets, forURLScheme: "mori-asset")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground"); view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.loadFileURL(AppPaths.web.appendingPathComponent("index.html"), allowingReadAccessTo: AppPaths.web)
        webView = view; return view
    }

    func synchronize(document: WritingDocument, mode: EditorMode, preferences: AppearancePreferences,
        focus: Bool, typewriter: Bool, workspaceURL: URL?) {
        var roots = document.url.map { [$0.deletingLastPathComponent()] } ?? []
        if let workspaceURL, let url = document.url, url.path.hasPrefix(workspaceURL.path + "/") { roots.append(workspaceURL) }
        assets.roots = roots
        let theme = preferences.theme
        let settings = WebEditorSettings(language: L10n.language.rawValue, theme: theme.rawValue, surface: theme.surface, text: theme.text, muted: theme.muted,
            accent: theme.accent, font: preferences.font.css, fontSize: preferences.fontSize, lineHeight: preferences.lineHeight,
            pageWidth: preferences.pageWidth, paperOpacity: preferences.paperOpacity, spellcheck: preferences.spellcheck,
            showLineNumbers: preferences.showLineNumbers, focusMode: focus, typewriterMode: typewriter, customCSS: preferences.customCSS)
        let payload = WebDocumentPayload(id: document.id.uuidString, startsInBody: document.startsInBody, markdown: document.content,
            directory: document.url?.deletingLastPathComponent().path ?? "", mode: mode.rawValue, settings: settings)
        pending = payload; sendPending()
    }

    private func sendPending() {
        guard ready, let pending, let encoded = encode(pending) else { return }
        let stamp = (encode(pending.settings) ?? "") + pending.mode + pending.directory
        if pending.id != lastID || pending.markdown != lastMarkdown {
            evaluate("window.Mori.load(\(encoded))")
            lastID = pending.id; lastMarkdown = pending.markdown; lastSettings = stamp
        } else if stamp != lastSettings {
            evaluate("window.Mori.configure(\(encoded))"); lastSettings = stamp
        }
    }

    func resetDocument() { lastID = nil; lastMarkdown = nil; objectWillChange.send() }

    func perform(_ name: String, payload: [String: Any] = [:]) {
        guard ready else { queued.append((name, payload)); return }
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let encoded = String(data: data, encoding: .utf8),
            let command = encode(name) else { return }
        evaluate("window.Mori.command(\(command), \(encoded))")
    }

    // ===== 让保存与退出先拿到编辑器最新内容 =====
    func flush(completion: @escaping () -> Void) {
        guard ready, let webView else { completion(); return }
        webView.evaluateJavaScript("window.Mori.flush()") { [weak self] result, error in
            if error == nil, let dictionary = result as? [String: Any], let idString = dictionary["id"] as? String,
                let id = UUID(uuidString: idString), let markdown = dictionary["markdown"] as? String {
                self?.lastMarkdown = markdown; self?.onChange?(id, markdown)
            }
            completion()
        }
    }

    func exportHTML(completion: @escaping (String?) -> Void) {
        guard ready, let webView else { completion(nil); return }
        webView.callAsyncJavaScript("return await window.Mori.exportHTML()", arguments: [:], in: nil, in: .page) { result in
            switch result { case .success(let value): completion(value as? String); case .failure: completion(nil) }
        }
    }

    func readMetadata(completion: @escaping ([String: Any]?) -> Void) {
        guard ready, let webView else { completion(nil); return }
        webView.evaluateJavaScript("window.Mori.metadata()") { result, _ in completion(result as? [String: Any]) }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            ready = true; sendPending()
            for (name, payload) in queued { perform(name, payload: payload) }; queued.removeAll()
        case "change":
            guard let idString = body["id"] as? String, let id = UUID(uuidString: idString), let markdown = body["markdown"] as? String else { return }
            if idString == lastID { lastMarkdown = markdown }
            onChange?(id, markdown)
        case "openURL": if let url = body["url"] as? String { onMessage?(.openURL(url)) }
        case "openArticle": if let path = body["path"] as? String { onMessage?(.openArticle(path)) }
        case "asset":
            guard let idString = body["id"] as? String, let id = UUID(uuidString: idString), let raw = body["data"] as? String,
                raw.count < 36 * 1024 * 1024, let data = Data(base64Encoded: raw), let name = body["name"] as? String else { return }
            onMessage?(.asset(id, data, name))
        case "action": if let name = body["name"] as? String { onMessage?(.action(name)) }
        case "unsupported": onMessage?(.unsupported)
        case "error": onMessage?(.error)
        default: break
        }
    }

    // ===== 导航仅允许应用自己的编辑器页面 =====
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        decisionHandler(url?.isFileURL == true && url?.path.hasPrefix(AppPaths.web.path + "/") == true ? .allow : .cancel)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false; lastID = nil; lastMarkdown = nil
        webView.loadFileURL(AppPaths.web.appendingPathComponent("index.html"), allowingReadAccessTo: AppPaths.web)
    }

    private func evaluate(_ script: String) {
        webView?.evaluateJavaScript(script) { [weak self] _, error in if error != nil { self?.onMessage?(.error) } }
    }

    private func encode<Value: Encodable>(_ value: Value) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
