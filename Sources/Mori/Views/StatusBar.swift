import SwiftUI

struct StatusBar: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    var body: some View {
        HStack(spacing: 13) {
            Menu {
                Text("字词：\(store.statistics.words)")
                Text("字符：\(store.statistics.characters)")
                Text("行数：\(store.statistics.lines)")
                Text("阅读时间：\(store.statistics.readingMinutes) 分钟")
            } label: { Text("\(store.statistics.words) 字词").font(.system(size: 10.5)) }
                .menuStyle(.borderlessButton).fixedSize()
            Text("约 \(store.statistics.readingMinutes) 分钟阅读").foregroundStyle(.secondary)
            if let notice = store.notice {
                Text(notice).foregroundStyle(.secondary).lineLimit(1)
                Button { store.notice = nil } label: { Image(systemName: "xmark").font(.system(size: 8)) }.buttonStyle(.plain)
            }
            Spacer(minLength: 8)
            if !store.focusMode && store.activeDocument != nil {
                ProgressView(value: min(Double(store.statistics.words) / Double(max(100, preferences.value.wordGoal)), 1))
                    .progressViewStyle(.linear).frame(width: 42).help("写作目标：\(preferences.value.wordGoal) 字词")
                Text("\(preferences.value.wordGoal)").foregroundStyle(.secondary)
            }
            Image(systemName: saveIcon).font(.system(size: 9))
            Text(saveLabel).foregroundStyle(.secondary)
            Button { store.focusMode.toggle() } label: {
                Image(systemName: store.focusMode ? "arrow.down.right.and.arrow.up.left" : "viewfinder").frame(width: 22, height: 20)
            }.buttonStyle(.plain).help("专注模式 ⌘⇧F")
        }
        .font(.system(size: 10)).padding(.horizontal, 25).frame(height: 33)
        .background(Color(hex: preferences.value.theme.surface).opacity(0.78))
    }

    private var saveIcon: String { store.activeDocument?.saveFailure != nil || store.activeDocument?.conflict == true ? "exclamationmark.circle" : "checkmark.circle" }
    private var saveLabel: String {
        guard let document = store.activeDocument else { return "就绪" }
        if document.conflict { return "需处理外部修改" }
        if document.saveFailure != nil { return "未能保存到文件" }
        if document.url == nil { return "草稿已保留" }
        if document.isDirty { return preferences.value.autosave ? "正在保存…" : "尚未保存" }
        return "已保存"
    }
}
