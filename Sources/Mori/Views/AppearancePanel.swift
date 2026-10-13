import SwiftUI
import MoriCore

struct AppearancePanel: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    private var value: AppearancePreferences { preferences.value }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("你的写作环境")).font(.custom("IowanOldStyle-Roman", size: 23))
                    Text(L10n.text("一张纸，一束光，还有你喜欢的风景。")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button(L10n.text("导入主题…"), action: preferences.importTheme)
                    Button(L10n.text("导出主题…"), action: preferences.exportTheme)
                    Divider()
                    Button(L10n.text("恢复默认外观")) { preferences.value = AppearancePreferences() }
                } label: { Image(systemName: "ellipsis").frame(width: 24) }.menuStyle(.borderlessButton).fixedSize()
                Button(L10n.text("完成")) { dismiss() }.buttonStyle(.borderedProminent)
            }.padding(24)
            Divider().opacity(0.4)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Picker(L10n.text("设置类型"), selection: $tab) {
                        Text(L10n.text("外观")).tag(0); Text(L10n.text("文字")).tag(1); Text(L10n.text("偏好")).tag(2)
                    }.pickerStyle(.segmented).padding(20)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            if tab == 0 { BackgroundControls() }
                            else if tab == 1 { typographyControls }
                            else { writingControls }
                        }.padding(.horizontal, 24).padding(.bottom, 25)
                    }.id(tab)
                }.frame(width: 385)
                Divider().opacity(0.4)
                AppearancePreview().padding(24).frame(maxWidth: .infinity)
            }
        }
        .frame(width: 850, height: 660)
        .background(Color(hex: value.theme.surface))
        .preferredColorScheme(value.theme.scheme)
        .tint(Color(hex: value.theme.accent))
        .alert(L10n.text("操作未完成"), isPresented: errorBinding) {
            Button(L10n.text("知道了"), role: .cancel) { preferences.errorMessage = nil }
        } message: { Text(L10n.text(preferences.errorMessage ?? "")) }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { preferences.errorMessage != nil }, set: { if !$0 { preferences.errorMessage = nil } })
    }

    private var typographyControls: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsSection(L10n.text("文章字体")) {
                Picker(L10n.text("字体"), selection: $preferences.value.font) { ForEach(WritingFont.allCases) { Text($0.label).tag($0) } }.labelsHidden().frame(maxWidth: .infinity)
                SettingsSlider(L10n.text("字号"), value: $preferences.value.fontSize, range: 13...32, suffix: "px")
                SettingsSlider(L10n.text("行距"), value: $preferences.value.lineHeight, range: 1.3...2.4, decimals: 2)
                SettingsSlider(L10n.text("纸面宽度"), value: $preferences.value.pageWidth, range: 480...1200, suffix: "px")
            }
            SettingsSection(L10n.text("自定义文章 CSS")) {
                Text(L10n.text("可设置文章字体、标题、引用、代码和表格样式。主题会随设置一起导出。")).font(.system(size: 10)).foregroundStyle(.secondary)
                TextEditor(text: $preferences.value.customCSS).font(.system(size: 10, design: .monospaced))
                    .scrollContentBackground(.hidden).frame(height: 180).padding(7)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 5))
                Button(L10n.text("填入示例")) { preferences.value.customCSS = ".markdown-content h1 { letter-spacing: -0.04em; }\n.markdown-content blockquote { border-left-width: 2px; }" }.font(.system(size: 11))
            }
        }
    }

    private var writingControls: some View {
        SettingsSection(L10n.text("写作偏好")) {
            Picker(L10n.text("界面语言"), selection: $preferences.language) {
                ForEach(AppLanguage.allCases) { Text(L10n.label($0)).tag($0) }
            }
            Text(L10n.text("切换后立即生效，不会更改文章内容。")).font(.system(size: 10)).foregroundStyle(.secondary)
            Divider().padding(.vertical, 4)
            Toggle(L10n.text("自动保存已命名的文章"), isOn: $preferences.value.autosave)
            Toggle(L10n.text("所见即所得模式拼写检查"), isOn: $preferences.value.spellcheck)
            Toggle(L10n.text("源码编辑器显示行号"), isOn: $preferences.value.showLineNumbers)
            HStack { Text(L10n.text("文章写作目标")); Spacer(); TextField(L10n.text("字词"), value: $preferences.value.wordGoal, format: .number).frame(width: 90).textFieldStyle(.roundedBorder) }
            Text(L10n.text("未命名草稿始终保留在本机。历史最多保留每篇文章最近 50 个版本。")).font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 12)
        }.font(.system(size: 12))
    }
}

struct SettingsSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSlider: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var suffix = ""
    var decimals = 0

    init(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String = "", decimals: Int = 0) {
        self.label = label; _value = value; self.range = range; self.suffix = suffix; self.decimals = decimals
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(label).font(.system(size: 11))
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(decimals))) + (suffix.isEmpty ? "" : " " + suffix)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range).controlSize(.small).accessibilityLabel(label)
        }
    }
}
