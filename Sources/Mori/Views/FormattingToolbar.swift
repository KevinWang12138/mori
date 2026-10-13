import SwiftUI

struct FormattingToolbar: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    var body: some View {
        HStack(spacing: 3) {
            Menu {
                Button("正文") { format("paragraph") }
                Button("一级标题") { format("heading1") }
                Button("二级标题") { format("heading2") }
                Button("三级标题") { format("heading3") }
            } label: { Text("Aa").font(.custom("IowanOldStyle-Roman", size: 16)).frame(width: 37, height: 26) }
                .menuStyle(.borderlessButton).fixedSize().help("段落样式")
            Divider().frame(height: 15).padding(.horizontal, 8)
            IconButton("加粗 ⌘B", icon: "bold") { format("bold") }
            IconButton("斜体 ⌘I", icon: "italic") { format("italic") }
            IconButton("删除线", icon: "strikethrough") { format("strike") }
            IconButton("插入链接 ⌘K", icon: "link") { format("link") }
            IconButton("插入图片", icon: "photo", action: store.chooseImage)
            Divider().frame(height: 15).padding(.horizontal, 8)
            IconButton("无序列表", icon: "list.bullet") { format("bullet") }
            IconButton("任务清单", icon: "checklist") { format("task") }
            IconButton("引用", icon: "text.quote") { format("quote") }
            Menu {
                Button("插入表格") { format("table") }
                Button("插入代码块") { format("codeblock") }
                Button("插入公式") { format("math") }
                Button("插入 Mermaid 图表") { format("mermaid") }
                Button("分隔线") { format("divider") }
                Divider()
                Button("增加表格行") { format("addRow") }
                Button("增加表格列") { format("addColumn") }
                Button("删除当前行") { format("deleteRow") }
                Button("删除当前列") { format("deleteColumn") }
                Button("删除表格") { format("deleteTable") }
            } label: { Image(systemName: "plus.circle").frame(width: 30, height: 30) }
                .menuStyle(.borderlessButton).fixedSize().help("更多插入与表格操作")
            Spacer()
            Text(store.activeDocument?.url == nil ? "本机草稿" : "Markdown")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
        }.padding(.horizontal, 21).frame(height: 42)
            .background(Color(hex: preferences.value.theme.surface).opacity(0.38))
            .disabled(store.activeDocument == nil)
    }

    private func format(_ name: String) { store.editor.perform(name) }
}
