import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    private var appearance: AppearancePreferences { preferences.value }

    var body: some View {
        ZStack {
            WallpaperView(preferences: appearance)
            VStack(spacing: 0) {
                WindowHeader()
                Divider().opacity(0.4)
                HStack(spacing: 0) {
                    if store.showSidebar && !store.focusMode {
                        LibrarySidebar().frame(width: 224)
                        Divider().opacity(0.35)
                    }
                    VStack(spacing: 0) {
                        if !store.focusMode { DocumentTabs(); FormattingToolbar() }
                        if let document = store.activeDocument {
                            if document.conflict { ConflictBanner() }
                            MarkdownEditorView(bridge: store.editor, document: document, mode: store.mode,
                                preferences: appearance, focus: store.focusMode, typewriter: store.typewriterMode, workspaceURL: store.workspaceURL)
                        } else { EmptyWorkspaceView() }
                        StatusBar()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if store.showInspector && !store.focusMode {
                        Divider().opacity(0.35)
                        ArticleInspector().frame(width: 270)
                    }
                }
            }
        }
        .frame(minWidth: 960, minHeight: 620)
        .tint(Color(hex: appearance.theme.accent))
        .foregroundStyle(Color(hex: appearance.theme.text))
        .preferredColorScheme(appearance.theme.scheme)
        .sheet(isPresented: $store.showAppearance) { AppearancePanel().environmentObject(preferences) }
        .sheet(isPresented: $store.showNewArticle) { NewArticleSheet().environmentObject(store) }
        .alert(L10n.text("操作未完成"), isPresented: errorBinding) { Button(L10n.text("知道了"), role: .cancel) { clearErrors() } } message: {
            Text(L10n.text(store.errorMessage ?? preferences.errorMessage ?? ""))
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil || (!store.showAppearance && preferences.errorMessage != nil) }, set: { if !$0 { clearErrors() } })
    }

    private func clearErrors() { store.errorMessage = nil; preferences.errorMessage = nil }
}

private struct EmptyWorkspaceView: View {
    @EnvironmentObject private var store: DocumentStore
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "leaf").font(.system(size: 34, weight: .ultraLight)).foregroundStyle(.secondary)
            Text(L10n.text("把想法写下来")).font(.custom("IowanOldStyle-Roman", size: 29))
            Text(L10n.text("从一张空白纸开始，或打开你的博客文章。")).font(.system(size: 13)).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button(L10n.text("新建文章")) { store.showNewArticle = true }.buttonStyle(.borderedProminent)
                Button(L10n.text("打开文章"), action: store.openPanel).buttonStyle(.bordered)
            }.padding(.top, 8)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ConflictBanner: View {
    @EnvironmentObject private var store: DocumentStore
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
            Text(L10n.text("磁盘文件已改变。当前稿件已保留。")).font(.system(size: 12))
            Spacer()
            Button(L10n.text("载入磁盘版本"), action: store.reloadExternalFile).buttonStyle(.borderless)
            Button(L10n.text("另存当前稿件")) { store.saveActive(asNewFile: true) }.buttonStyle(.borderless)
        }.padding(.horizontal, 24).padding(.vertical, 10).foregroundStyle(Color(hex: "#8C662D"))
            .background(Color(hex: "#E8CB8A").opacity(0.18))
    }
}
