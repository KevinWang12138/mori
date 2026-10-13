import SwiftUI

struct WindowHeader: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        HStack(spacing: 14) {
            Text("mori").font(.custom("IowanOldStyle-BoldItalic", size: 25)).tracking(-1)
            IconButton(L10n.text("显示文章库"), icon: "sidebar.left") { store.showSidebar.toggle() }
            Spacer()
            Picker(L10n.text("编辑模式"), selection: $store.mode) {
                ForEach(EditorMode.allCases) { mode in Label(mode.label, systemImage: mode.icon).tag(mode) }
            }.pickerStyle(.segmented).frame(width: 230).help(L10n.text("写作 / 源码 / 分栏预览"))
            Spacer()
            IconButton(L10n.text("文章大纲与博客信息"), icon: "sidebar.right") { store.showInspector.toggle() }
            IconButton(L10n.text("写作环境"), icon: "slider.horizontal.3") { store.showAppearance = true }
            Menu {
                Button(L10n.text("导出 HTML…")) { store.exportArticle(.html) }
                Button(L10n.text("导出 PDF…")) { store.exportArticle(.pdf) }
                Button(L10n.text("复制 Markdown"), action: store.copyMarkdown)
                Button(L10n.text("复制 HTML"), action: store.copyHTML)
            } label: { Image(systemName: "square.and.arrow.up").frame(width: 30, height: 30) }
                .menuStyle(.borderlessButton).fixedSize().help(L10n.text("导出与复制"))
        }
        .padding(.leading, 82).padding(.trailing, 22).frame(height: 58)
        .background(Color(hex: preferences.value.theme.surface).opacity(0.86))
    }
}

struct IconButton: View {
    var label: String
    var icon: String
    var action: () -> Void
    @State private var hovering = false

    init(_ label: String, icon: String, action: @escaping () -> Void) {
        self.label = label; self.icon = icon; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium)).frame(width: 30, height: 30)
                .background(.primary.opacity(hovering ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain).help(label).accessibilityLabel(label).onHover { hovering = $0 }
    }
}
