import SwiftUI
import WebKit

struct MarkdownEditorView: NSViewRepresentable {
    @ObservedObject var bridge: EditorBridge
    var document: WritingDocument
    var mode: EditorMode
    var preferences: AppearancePreferences
    var focus: Bool
    var typewriter: Bool
    var workspaceURL: URL?

    func makeNSView(context: Context) -> WKWebView { bridge.makeWebView() }

    func updateNSView(_ view: WKWebView, context: Context) {
        bridge.synchronize(document: document, mode: mode, preferences: preferences, focus: focus, typewriter: typewriter, workspaceURL: workspaceURL)
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: ()) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "mori")
    }
}
