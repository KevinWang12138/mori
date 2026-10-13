import SwiftUI
import MoriCore

struct MoriCommands: Commands {
    @ObservedObject var store: DocumentStore
    @ObservedObject var preferences: PreferencesStore
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L10n.text("新建文章…")) { store.showNewArticle = true }.keyboardShortcut("n")
            Button(L10n.text("新建空白草稿")) { store.newDocument() }.keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button(L10n.text("打开文章…"), action: store.openPanel).keyboardShortcut("o")
            Button(L10n.text("打开博客文件夹…"), action: store.chooseWorkspace).keyboardShortcut("o", modifiers: [.command, .shift])
            Menu(L10n.text("最近打开")) {
                ForEach(NSDocumentController.shared.recentDocumentURLs, id: \.path) { url in
                    Button(url.lastPathComponent) { store.open(url) }
                }
            }
        }
        CommandGroup(replacing: .saveItem) {
            Button(L10n.text("保存")) { store.saveActive() }.keyboardShortcut("s").disabled(store.activeDocument == nil)
            Button(L10n.text("另存为…")) { store.saveActive(asNewFile: true) }.keyboardShortcut("s", modifiers: [.command, .shift]).disabled(store.activeDocument == nil)
            Button(L10n.text("关闭文章")) { if let id = store.activeID { store.close(id) } }.keyboardShortcut("w").disabled(store.activeDocument == nil)
        }
        CommandGroup(replacing: .importExport) {
            Button(L10n.text("导出 HTML…")) { store.exportArticle(.html) }.disabled(store.activeDocument == nil)
            Button(L10n.text("导出 PDF…")) { store.exportArticle(.pdf) }.disabled(store.activeDocument == nil)
            Button(L10n.text("复制 Markdown"), action: store.copyMarkdown).disabled(store.activeDocument == nil)
            Button(L10n.text("复制 HTML"), action: store.copyHTML).disabled(store.activeDocument == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button(L10n.text("打印 / 存为 PDF…")) { store.exportArticle(.print) }.keyboardShortcut("p").disabled(store.activeDocument == nil)
        }
        CommandGroup(replacing: .undoRedo) {
            Button(L10n.text("撤销")) { format("undo") }.keyboardShortcut("z")
            Button(L10n.text("重做")) { format("redo") }.keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(after: .textEditing) {
            Button(L10n.text("查找与替换…")) { format("find") }.keyboardShortcut("f").disabled(store.activeDocument == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button(L10n.text("写作环境…")) { store.showAppearance = true }.keyboardShortcut(",")
            Menu(L10n.text("语言")) {
                Picker(L10n.text("界面语言"), selection: $preferences.language) {
                    ForEach(AppLanguage.allCases) { Text(L10n.label($0)).tag($0) }
                }
            }
        }
        CommandMenu(L10n.text("格式")) {
            Button(L10n.text("加粗")) { format("bold") }.keyboardShortcut("b")
            Button(L10n.text("斜体")) { format("italic") }.keyboardShortcut("i")
            Button(L10n.text("链接…")) { format("link") }.keyboardShortcut("k")
            Button(L10n.text("删除线")) { format("strike") }
            Button(L10n.text("行内代码")) { format("code") }
            Divider()
            Button(L10n.text("一级标题")) { format("heading1") }.keyboardShortcut("1")
            Button(L10n.text("二级标题")) { format("heading2") }.keyboardShortcut("2")
            Button(L10n.text("三级标题")) { format("heading3") }.keyboardShortcut("3")
            Button(L10n.text("正文")) { format("paragraph") }.keyboardShortcut("0")
            Divider()
            Button(L10n.text("无序列表")) { format("bullet") }
            Button(L10n.text("有序列表")) { format("ordered") }
            Button(L10n.text("任务清单")) { format("task") }
            Button(L10n.text("引用")) { format("quote") }
            Divider()
            Button(L10n.text("插入图片…"), action: store.chooseImage)
            Button(L10n.text("表格")) { format("table") }
            Button(L10n.text("代码块")) { format("codeblock") }
            Button(L10n.text("公式")) { format("math") }
            Button(L10n.text("Mermaid 图表")) { format("mermaid") }
        }
        CommandMenu(L10n.text("写作")) {
            Toggle(L10n.text("专注模式"), isOn: $store.focusMode).keyboardShortcut("f", modifiers: [.command, .shift])
            Toggle(L10n.text("打字机模式"), isOn: $store.typewriterMode).keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button(L10n.text("所见即所得")) { store.mode = .rich }.keyboardShortcut("r", modifiers: [.command, .shift])
            Button(L10n.text("源码模式")) { store.mode = .source }.keyboardShortcut("m", modifiers: [.command, .shift])
            Button(L10n.text("分栏预览")) { store.mode = .split }.keyboardShortcut("p", modifiers: [.command, .shift])
            Divider()
            Toggle(L10n.text("显示文章库"), isOn: $store.showSidebar)
            Toggle(L10n.text("显示文章信息"), isOn: $store.showInspector)
            Button(L10n.text("显示博客元信息")) { store.inspector = .blog; store.showInspector = true }
            Button(L10n.text("显示历史版本")) { store.inspector = .history; store.showInspector = true }
        }
        CommandGroup(replacing: .help) {
            Button(L10n.text("Mori 使用说明")) { NSWorkspace.shared.open(URL(string: "https://github.com/KevinWang12138/mori#readme")!) }
            Button(L10n.text("反馈问题")) { NSWorkspace.shared.open(URL(string: "https://github.com/KevinWang12138/mori/issues")!) }
        }
    }

    private func format(_ name: String) { store.editor.perform(name) }
}
