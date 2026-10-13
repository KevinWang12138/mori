import SwiftUI
import MoriCore

struct NewArticleSheet: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var template: BlogTemplate = .blank
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.text("一篇新的文章")).font(.custom("IowanOldStyle-Roman", size: 26))
                Text(L10n.text("先给想法起一个名字。")).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            TextField(L10n.text("文章标题"), text: $title).textFieldStyle(.roundedBorder).font(.system(size: 14)).focused($titleFocused).onSubmit(createArticle)
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("文章模板")).font(.system(size: 11)).foregroundStyle(.secondary)
                Picker(L10n.text("模板"), selection: $template) { ForEach(BlogTemplate.allCases) { Text(L10n.text($0.label)).tag($0) } }.pickerStyle(.segmented)
                Text(template == .blank ? L10n.text("从标题和空白正文开始。") : L10n.format("自动准备 %@ 的 YAML 元信息，后续可在博客面板编辑。", template.label))
                    .font(.system(size: 10)).foregroundStyle(.secondary).frame(height: 28, alignment: .topLeading)
            }
            HStack {
                Text(L10n.text("草稿自动保留在本机")).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("取消")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L10n.text("开始写作"), action: createArticle).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width: 490).onAppear { titleFocused = true }
    }

    private func createArticle() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        store.newDocument(template: template, title: name.isEmpty ? L10n.text("未命名文章") : name)
        dismiss()
    }
}
