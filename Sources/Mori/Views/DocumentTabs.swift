import SwiftUI

struct DocumentTabs: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(store.documents) { document in DocumentTab(document: document) }
                }
            }
            IconButton("新建文章", icon: "plus") { store.newDocument() }.padding(.horizontal, 8)
        }.frame(height: 39)
            .background(Color(hex: preferences.value.theme.surface).opacity(0.58))
            .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }
}

private struct DocumentTab: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    var document: WritingDocument
    @State private var hovering = false
    private var active: Bool { store.activeID == document.id }
    var body: some View {
        HStack(spacing: 8) {
            Button { store.activate(document.id) } label: {
                HStack(spacing: 7) {
                    if document.isDirty { Circle().fill(Color(hex: preferences.value.theme.accent)).frame(width: 5, height: 5) }
                    else { Image(systemName: "doc.text").font(.system(size: 10)).opacity(0.55) }
                    Text(document.filename).font(.system(size: 11.5)).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Button { store.close(document.id) } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)).frame(width: 18, height: 20).opacity(active || hovering ? 0.6 : 0)
            }.buttonStyle(.plain).help("关闭文章")
        }
        .padding(.leading, 14).padding(.trailing, 6).frame(width: 183, height: 39)
        .background(Color(hex: preferences.value.theme.surface).opacity(active ? 0.92 : 0))
        .overlay(alignment: .bottom) { if active { Rectangle().fill(Color(hex: preferences.value.theme.accent)).frame(height: 2).padding(.horizontal, 12) } }
        .overlay(alignment: .trailing) { Divider().frame(height: 16).opacity(0.4) }
        .onHover { hovering = $0 }
        .help(document.url?.path ?? "尚未保存到文件的本机草稿")
    }
}
