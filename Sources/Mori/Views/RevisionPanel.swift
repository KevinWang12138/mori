import SwiftUI
import MoriCore

struct RevisionPanel: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var selected: UUID?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("历史版本").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                    Spacer()
                    Button(action: store.loadRevisions) { Image(systemName: "arrow.clockwise").font(.system(size: 10)) }.buttonStyle(.plain).help("刷新历史")
                }
                Text("恢复之前会先保留当前稿件。版本只存于本机。").font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
                if store.revisions.isEmpty {
                    Text("保存文章后，历史版本会出现在这里。").font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 18)
                }
                ForEach(store.revisions) { revision in
                    VStack(alignment: .leading, spacing: 10) {
                        Button { selected = selected == revision.id ? nil : revision.id } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(revision.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11, weight: .medium))
                                Text("\(WritingStatistics(text: revision.content).words) 字词").font(.system(size: 9)).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if selected == revision.id {
                            Text(String(FrontMatter.split(revision.content).body.prefix(700))).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(12).textSelection(.enabled)
                            Button("恢复这个版本") { store.restoreRevision(revision); selected = nil }.controlSize(.small).buttonStyle(.bordered)
                        }
                    }.padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 5))
                }
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
        .onAppear(perform: store.loadRevisions)
        .onChange(of: store.activeID) { _, _ in selected = nil; store.loadRevisions() }
    }
}
