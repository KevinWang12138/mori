import SwiftUI

struct MoriCommands: Commands {
    @ObservedObject var store: DocumentStore
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建文章…") { store.showNewArticle = true }.keyboardShortcut("n")
            Button("新建空白草稿") { store.newDocument() }.keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("打开文章…", action: store.openPanel).keyboardShortcut("o")
            Button("打开博客文件夹…", action: store.chooseWorkspace).keyboardShortcut("o", modifiers: [.command, .shift])
            Menu("最近打开") {
                ForEach(NSDocumentController.shared.recentDocumentURLs, id: \.path) { url in
                    Button(url.lastPathComponent) { store.open(url) }
                }
            }
        }
        CommandGroup(replacing: .saveItem) {
            Button("保存") { store.saveActive() }.keyboardShortcut("s").disabled(store.activeDocument == nil)
            Button("另存为…") { store.saveActive(asNewFile: true) }.keyboardShortcut("s", modifiers: [.command, .shift]).disabled(store.activeDocument == nil)
            Button("关闭文章") { if let id = store.activeID { store.close(id) } }.keyboardShortcut("w").disabled(store.activeDocument == nil)
        }
        CommandGroup(replacing: .importExport) {
            Button("导出 HTML…") { store.exportArticle(.html) }.disabled(store.activeDocument == nil)
            Button("导出 PDF…") { store.exportArticle(.pdf) }.disabled(store.activeDocument == nil)
            Button("复制 Markdown", action: store.copyMarkdown).disabled(store.activeDocument == nil)
            Button("复制 HTML", action: store.copyHTML).disabled(store.activeDocument == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("打印 / 存为 PDF…") { store.exportArticle(.print) }.keyboardShortcut("p").disabled(store.activeDocument == nil)
        }
        CommandGroup(replacing: .undoRedo) {
            Button("撤销") { format("undo") }.keyboardShortcut("z")
            Button("重做") { format("redo") }.keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(after: .textEditing) {
            Button("查找与替换…") { format("find") }.keyboardShortcut("f").disabled(store.activeDocument == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button("写作环境…") { store.showAppearance = true }.keyboardShortcut(",")
        }
        CommandMenu("格式") {
            Button("加粗") { format("bold") }.keyboardShortcut("b")
            Button("斜体") { format("italic") }.keyboardShortcut("i")
            Button("链接…") { format("link") }.keyboardShortcut("k")
            Button("删除线") { format("strike") }
            Button("行内代码") { format("code") }
            Divider()
            Button("一级标题") { format("heading1") }.keyboardShortcut("1")
            Button("二级标题") { format("heading2") }.keyboardShortcut("2")
            Button("三级标题") { format("heading3") }.keyboardShortcut("3")
            Button("正文") { format("paragraph") }.keyboardShortcut("0")
            Divider()
            Button("无序列表") { format("bullet") }
            Button("有序列表") { format("ordered") }
            Button("任务清单") { format("task") }
            Button("引用") { format("quote") }
            Divider()
            Button("插入图片…", action: store.chooseImage)
            Button("表格") { format("table") }
            Button("代码块") { format("codeblock") }
            Button("公式") { format("math") }
            Button("Mermaid 图表") { format("mermaid") }
        }
        CommandMenu("写作") {
            Toggle("专注模式", isOn: $store.focusMode).keyboardShortcut("f", modifiers: [.command, .shift])
            Toggle("打字机模式", isOn: $store.typewriterMode).keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("所见即所得") { store.mode = .rich }.keyboardShortcut("r", modifiers: [.command, .shift])
            Button("源码模式") { store.mode = .source }.keyboardShortcut("m", modifiers: [.command, .shift])
            Button("分栏预览") { store.mode = .split }.keyboardShortcut("p", modifiers: [.command, .shift])
            Divider()
            Toggle("显示文章库", isOn: $store.showSidebar)
            Toggle("显示文章信息", isOn: $store.showInspector)
            Button("显示博客元信息") { store.inspector = .blog; store.showInspector = true }
            Button("显示历史版本") { store.inspector = .history; store.showInspector = true }
        }
        CommandGroup(replacing: .help) {
            Button("Mori 使用说明") { NSWorkspace.shared.open(URL(string: "https://github.com/KevinWang12138/mori#readme")!) }
            Button("反馈问题") { NSWorkspace.shared.open(URL(string: "https://github.com/KevinWang12138/mori/issues")!) }
        }
    }

    private func format(_ name: String) { store.editor.perform(name) }
}
