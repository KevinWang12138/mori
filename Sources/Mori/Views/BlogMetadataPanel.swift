import SwiftUI
import MoriCore

struct BlogMetadataPanel: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var title = ""
    @State private var description = ""
    @State private var date = ""
    @State private var slug = ""
    @State private var tags = ""
    @State private var categories = ""
    @State private var cover = ""
    @State private var draft = true
    @State private var dateKey = "date"
    @State private var coverKey = "cover"
    @State private var loadedID: UUID?
    @State private var baseline: [String: String] = [:]
    @State private var baselineDraft = true
    private var modified: Bool { fieldValues() != baseline || draft != baselineDraft }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text(L10n.text("文章元信息")).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                field(L10n.text("标题"), text: $title)
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.text("摘要")).font(.system(size: 10)).foregroundStyle(.secondary)
                    TextEditor(text: $description).font(.system(size: 11)).scrollContentBackground(.hidden).frame(height: 72).padding(5)
                        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 4))
                    Text(L10n.format("%d 字符", description.count)).font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                field(L10n.text("发布日期"), text: $date)
                field(L10n.text("URL 标识 / slug"), text: $slug)
                field(L10n.text("标签 · 用逗号分隔"), text: $tags)
                field(L10n.text("分类 · 用逗号分隔"), text: $categories)
                field(L10n.text("封面路径或 HTTPS 地址"), text: $cover)
                Toggle(L10n.text("标记为草稿"), isOn: $draft).font(.system(size: 11))
                Button(L10n.text("应用到 Front Matter"), action: applyMetadata).buttonStyle(.borderedProminent).controlSize(.small).frame(maxWidth: .infinity)
                Text(L10n.text("未列出的 YAML 字段会保留。复杂元信息可在源码模式中直接编辑。")).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
                Divider().padding(.vertical, 4)
                Button(L10n.text("在 Finder 中显示文章"), action: store.revealCurrentFile).font(.system(size: 10)).disabled(store.activeDocument?.url == nil)
            }.padding(.horizontal, 22).padding(.bottom, 24)
        }
        .onAppear(perform: loadMetadata)
        .onChange(of: store.activeID) { _, _ in loadMetadata() }
        .onChange(of: store.activeDocument?.content) { _, _ in if !modified { loadMetadata() } }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("", text: text).font(.system(size: 11)).textFieldStyle(.roundedBorder)
        }
    }

    // ===== 读取博客字段并保持各平台已有日期与封面键名 =====
    private func loadMetadata() {
        let content = store.activeDocument?.content ?? ""
        loadedID = store.activeID
        title = FrontMatter.value("title", in: content) ?? ""
        description = FrontMatter.value("description", in: content) ?? ""
        dateKey = FrontMatter.value("pubDate", in: content) != nil ? "pubDate" : "date"
        coverKey = FrontMatter.value("heroImage", in: content) != nil ? "heroImage" : "cover"
        date = FrontMatter.value(dateKey, in: content) ?? ""
        cover = FrontMatter.value(coverKey, in: content) ?? ""
        slug = FrontMatter.value("slug", in: content) ?? ""
        tags = cleanArray(FrontMatter.value("tags", in: content) ?? "")
        categories = cleanArray(FrontMatter.value("categories", in: content) ?? "")
        draft = FrontMatter.value("draft", in: content) != "false"
        captureBaseline()
        let id = loadedID
        store.editor.readMetadata { metadata in
            guard let metadata, store.activeID == id, !modified else { return }
            title = metadata["title"] as? String ?? title
            description = metadata["description"] as? String ?? description
            date = metadata[dateKey] as? String ?? date
            cover = metadata[coverKey] as? String ?? cover
            slug = metadata["slug"] as? String ?? slug
            if let items = metadata["tags"] as? [String] { tags = items.joined(separator: ", ") }
            if let items = metadata["categories"] as? [String] { categories = items.joined(separator: ", ") }
            draft = metadata["draft"] as? Bool ?? draft
            captureBaseline()
        }
    }

    private func applyMetadata() {
        guard store.activeID == loadedID else { return }
        applyChangedFields()
    }

    private func applyChangedFields() {
        let current = fieldValues()
        let isNew = FrontMatter.split(store.activeDocument?.content ?? "").prefix.isEmpty
        var changes: [String: Any] = [:]
        for (key, value) in current where value != baseline[key] || (isNew && !value.isEmpty) {
            changes[key] = ["tags", "categories"].contains(key) ? array(value) : value
        }
        if draft != baselineDraft || isNew { changes["draft"] = draft }
        guard !changes.isEmpty else { return }
        store.editor.perform("setMetadata", payload: changes)
        captureBaseline()
    }

    private func fieldValues() -> [String: String] {
        ["title": title, "description": description, dateKey: date, "slug": slug, "tags": tags, "categories": categories, coverKey: cover]
    }

    private func captureBaseline() { baseline = fieldValues(); baselineDraft = draft }

    private func array(_ value: String) -> [String] {
        value.components(separatedBy: CharacterSet(charactersIn: ",，")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func cleanArray(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
    }
}
