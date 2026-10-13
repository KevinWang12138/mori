import SwiftUI

struct StatusBar: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var preferences: PreferencesStore
    var body: some View {
        HStack(spacing: 13) {
            Menu {
                Text(L10n.format("字词：%d", store.statistics.words))
                Text(L10n.format("字符：%d", store.statistics.characters))
                Text(L10n.format("行数：%d", store.statistics.lines))
                Text(L10n.format("阅读时间：%d 分钟", store.statistics.readingMinutes))
            } label: { Text(L10n.format("%d 字词", store.statistics.words)).font(.system(size: 10.5)) }
                .menuStyle(.borderlessButton).fixedSize()
            Text(L10n.format("约 %d 分钟阅读", store.statistics.readingMinutes)).foregroundStyle(.secondary)
            if let notice = store.notice {
                Text(L10n.text(notice)).foregroundStyle(.secondary).lineLimit(1)
                Button { store.notice = nil } label: { Image(systemName: "xmark").font(.system(size: 8)) }.buttonStyle(.plain)
            }
            Spacer(minLength: 8)
            if !store.focusMode && store.activeDocument != nil {
                ProgressView(value: min(Double(store.statistics.words) / Double(max(100, preferences.value.wordGoal)), 1))
                    .progressViewStyle(.linear).frame(width: 42).help(L10n.format("写作目标：%d 字词", preferences.value.wordGoal))
                Text("\(preferences.value.wordGoal)").foregroundStyle(.secondary)
            }
            Image(systemName: saveIcon).font(.system(size: 9))
            Text(saveLabel).foregroundStyle(.secondary)
            Button { store.focusMode.toggle() } label: {
                Image(systemName: store.focusMode ? "arrow.down.right.and.arrow.up.left" : "viewfinder").frame(width: 22, height: 20)
            }.buttonStyle(.plain).help(L10n.text("专注模式 ⌘⇧F"))
        }
        .font(.system(size: 10)).padding(.horizontal, 25).frame(height: 33)
        .background(Color(hex: preferences.value.theme.surface).opacity(0.78))
    }

    private var saveIcon: String { store.activeDocument?.saveFailure != nil || store.activeDocument?.conflict == true ? "exclamationmark.circle" : "checkmark.circle" }
    private var saveLabel: String {
        guard let document = store.activeDocument else { return L10n.text("就绪") }
        if document.conflict { return L10n.text("需处理外部修改") }
        if document.saveFailure != nil { return L10n.text("未能保存到文件") }
        if document.url == nil { return L10n.text("草稿已保留") }
        if document.isDirty { return preferences.value.autosave ? L10n.text("正在保存…") : L10n.text("尚未保存") }
        return L10n.text("已保存")
    }
}
