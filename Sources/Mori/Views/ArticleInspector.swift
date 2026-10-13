import SwiftUI

struct ArticleInspector: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    var body: some View {
        VStack(spacing: 0) {
            Picker("文章信息", selection: $store.inspector) { ForEach(InspectorPanel.allCases) { Text($0.label).tag($0) } }
                .pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 18)
            if store.activeDocument == nil {
                Text("打开一篇文章后查看详细信息。").font(.system(size: 11)).foregroundStyle(.secondary).padding(24)
                Spacer()
            } else {
                switch store.inspector {
                case .outline: OutlinePanel()
                case .blog: BlogMetadataPanel()
                case .history: RevisionPanel()
                }
            }
        }.background(Color(hex: preferences.value.theme.surface).opacity(preferences.value.sidebarOpacity))
    }
}

private struct OutlinePanel: View {
    @EnvironmentObject private var store: DocumentStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                Text("文章大纲").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary).padding(.bottom, 12)
                if store.headings.isEmpty {
                    Text("输入 # 加空格开始写标题。标题会出现在这里。").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                }
                ForEach(Array(store.headings.enumerated()), id: \.element.id) { index, heading in
                    Button { store.editor.perform("jump", payload: ["index": index, "line": heading.line]) } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text(String(heading.level)).font(.system(size: 8, design: .monospaced)).foregroundStyle(.tertiary).padding(.top, 3)
                            Text(heading.title).font(.system(size: 11.5, weight: heading.level == 1 ? .medium : .regular)).lineLimit(2)
                            Spacer(minLength: 0)
                        }.padding(.vertical, 8).padding(.leading, CGFloat(max(0, heading.level - 1)) * 10).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 21).padding(.bottom, 22)
        }
    }
}
