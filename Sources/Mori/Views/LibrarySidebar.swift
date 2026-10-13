import SwiftUI
import MoriCore

struct LibrarySidebar: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var recentURLs: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("文章库").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                IconButton("打开博客文件夹", icon: "folder.badge.plus", action: store.chooseWorkspace)
            }.padding(.horizontal, 18).padding(.top, 18)
            Button { store.showNewArticle = true } label: {
                HStack { Image(systemName: "plus").font(.system(size: 10)); Text("新建文章").font(.system(size: 12)); Spacer(); Text("⌘N").font(.system(size: 10)).foregroundStyle(.secondary) }
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(Color(hex: preferences.value.theme.accent).opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            }.buttonStyle(.plain).padding(.horizontal, 16).padding(.top, 10)
            searchField.padding(.horizontal, 16).padding(.top, 18)
            if store.workspaceURL != nil {
                HStack(spacing: 5) {
                    Button { store.searchContent.toggle(); store.indexSearchContent() } label: {
                        Label("搜正文", systemImage: store.searchContent ? "checkmark.square" : "square").font(.system(size: 10))
                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                    Spacer()
                    Button { store.sortByRecent.toggle() } label: {
                        Image(systemName: store.sortByRecent ? "clock" : "textformat.abc").font(.system(size: 10))
                    }.buttonStyle(.plain).help(store.sortByRecent ? "按最近修改排序" : "按路径排序")
                    Button(action: store.refreshWorkspace) { Image(systemName: "arrow.clockwise").font(.system(size: 10)) }.buttonStyle(.plain).help("刷新文章库")
                }.padding(.horizontal, 19).padding(.top, 9)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if !store.documents.filter({ $0.url == nil }).isEmpty {
                        sectionLabel("草稿")
                        ForEach(store.documents.filter { $0.url == nil && (store.query.isEmpty || $0.title.localizedCaseInsensitiveContains(store.query) || (store.searchContent && $0.content.localizedCaseInsensitiveContains(store.query))) }) { document in
                            sidebarRow(title: document.title, subtitle: "本机草稿", icon: "pencil.line", selected: store.activeID == document.id) { store.activate(document.id) }
                        }
                    }
                    if let root = store.workspaceURL {
                        HStack {
                            sectionLabel(root.lastPathComponent)
                            Spacer()
                            Text("\(store.visibleArticles.count)").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 18)
                        }
                        if store.visibleArticles.isEmpty {
                            Text(store.query.isEmpty ? "文件夹中还没有 Markdown 文章。" : "没有找到匹配的文章。")
                                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 12).padding(.horizontal, 8)
                        }
                        ForEach(store.visibleArticles) { article in
                            sidebarRow(title: article.url.deletingPathExtension().lastPathComponent,
                                subtitle: article.relativePath.contains("/") ? article.relativePath : nil,
                                icon: "doc.text", selected: store.activeDocument?.url == article.url) { store.open(article.url) }
                            .contextMenu {
                                Button("打开") { store.open(article.url) }
                                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([article.url]) }
                            }
                        }
                    } else {
                        sectionLabel("最近打开")
                        ForEach(recentURLs.filter { store.query.isEmpty || $0.lastPathComponent.localizedCaseInsensitiveContains(store.query) }, id: \.path) { url in
                            sidebarRow(title: url.deletingPathExtension().lastPathComponent, subtitle: url.deletingLastPathComponent().lastPathComponent,
                                icon: "doc.text", selected: store.activeDocument?.url == url) { store.open(url) }
                        }
                        Button(action: store.chooseWorkspace) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "folder").font(.system(size: 17, weight: .light))
                                Text("打开博客文件夹").font(.system(size: 12, weight: .medium))
                                Text("把文章和图片留在熟悉的位置。").font(.system(size: 10)).foregroundStyle(.secondary)
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain).padding(.top, 14)
                    }
                }.padding(.horizontal, 13).padding(.bottom, 18)
            }.padding(.top, 5)
            Spacer(minLength: 0)
            Divider().opacity(0.35).padding(.horizontal, 16)
            HStack(spacing: 7) {
                Image(systemName: "internaldrive").font(.system(size: 10))
                Text("文件属于你 · 离线写作").font(.system(size: 10))
            }.foregroundStyle(.secondary).padding(19)
        }
        .background(Color(hex: preferences.value.theme.surface).opacity(preferences.value.sidebarOpacity))
        .onAppear(perform: loadRecent)
        .onChange(of: store.documents.count) { _, _ in loadRecent() }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
            TextField("搜索文章…", text: $store.query).textFieldStyle(.plain).font(.system(size: 11.5))
            if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 10)) }.buttonStyle(.plain).foregroundStyle(.secondary) }
        }.padding(.horizontal, 10).frame(height: 30).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 5))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(0.9).foregroundStyle(.secondary).padding(.horizontal, 7).padding(.top, 20).padding(.bottom, 7)
    }

    private func sidebarRow(title: String, subtitle: String?, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 11.5, weight: selected ? .medium : .regular)).lineLimit(1)
                    if let subtitle { Text(subtitle).font(.system(size: 9.5)).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 9).padding(.vertical, 9).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: preferences.value.theme.accent).opacity(selected ? 0.09 : 0), in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func loadRecent() { recentURLs = Array(NSDocumentController.shared.recentDocumentURLs.prefix(8)) }
}
