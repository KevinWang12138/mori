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
                Text("一篇新的文章").font(.custom("IowanOldStyle-Roman", size: 26))
                Text("先给想法起一个名字。").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            TextField("文章标题", text: $title).textFieldStyle(.roundedBorder).font(.system(size: 14)).focused($titleFocused).onSubmit(createArticle)
            VStack(alignment: .leading, spacing: 10) {
                Text("文章模板").font(.system(size: 11)).foregroundStyle(.secondary)
                Picker("模板", selection: $template) { ForEach(BlogTemplate.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                Text(template == .blank ? "从标题和空白正文开始。" : "自动准备 \(template.label) 的 YAML 元信息，后续可在博客面板编辑。")
                    .font(.system(size: 10)).foregroundStyle(.secondary).frame(height: 28, alignment: .topLeading)
            }
            HStack {
                Text("草稿自动保留在本机").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("开始写作", action: createArticle).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width: 490).onAppear { titleFocused = true }
    }

    private func createArticle() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        store.newDocument(template: template, title: name.isEmpty ? "未命名文章" : name)
        dismiss()
    }
}
