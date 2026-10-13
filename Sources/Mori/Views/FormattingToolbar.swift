import SwiftUI

struct FormattingToolbar: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    var body: some View {
        HStack(spacing: 3) {
            Menu {
                Button(L10n.text("正文")) { format("paragraph") }
                Button(L10n.text("一级标题")) { format("heading1") }
                Button(L10n.text("二级标题")) { format("heading2") }
                Button(L10n.text("三级标题")) { format("heading3") }
            } label: { Text("Aa").font(.custom("IowanOldStyle-Roman", size: 16)).frame(width: 37, height: 26) }
                .menuStyle(.borderlessButton).fixedSize().help(L10n.text("段落样式"))
            Divider().frame(height: 15).padding(.horizontal, 8)
            IconButton(L10n.text("加粗 ⌘B"), icon: "bold") { format("bold") }
            IconButton(L10n.text("斜体 ⌘I"), icon: "italic") { format("italic") }
            IconButton(L10n.text("删除线"), icon: "strikethrough") { format("strike") }
            IconButton(L10n.text("插入链接 ⌘K"), icon: "link") { format("link") }
            IconButton(L10n.text("插入图片"), icon: "photo", action: store.chooseImage)
            Divider().frame(height: 15).padding(.horizontal, 8)
            IconButton(L10n.text("无序列表"), icon: "list.bullet") { format("bullet") }
            IconButton(L10n.text("任务清单"), icon: "checklist") { format("task") }
            IconButton(L10n.text("引用"), icon: "text.quote") { format("quote") }
            Menu {
                Button(L10n.text("插入表格")) { format("table") }
                Button(L10n.text("插入代码块")) { format("codeblock") }
                Button(L10n.text("插入公式")) { format("math") }
                Button(L10n.text("插入 Mermaid 图表")) { format("mermaid") }
                Button(L10n.text("分隔线")) { format("divider") }
                Divider()
                Button(L10n.text("增加表格行")) { format("addRow") }
                Button(L10n.text("增加表格列")) { format("addColumn") }
                Button(L10n.text("删除当前行")) { format("deleteRow") }
                Button(L10n.text("删除当前列")) { format("deleteColumn") }
                Button(L10n.text("删除表格")) { format("deleteTable") }
            } label: { Image(systemName: "plus.circle").frame(width: 30, height: 30) }
                .menuStyle(.borderlessButton).fixedSize().help(L10n.text("更多插入与表格操作"))
            Spacer()
            Text(store.activeDocument?.url == nil ? L10n.text("本机草稿") : "Markdown")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
        }.padding(.horizontal, 21).frame(height: 42)
            .background(Color(hex: preferences.value.theme.surface).opacity(0.38))
            .disabled(store.activeDocument == nil)
    }

    private func format(_ name: String) { store.editor.perform(name) }
}
