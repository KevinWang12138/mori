import SwiftUI

struct BackgroundControls: View {
    @EnvironmentObject private var preferences: PreferencesStore
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsSection(L10n.text("纸与墨")) {
                HStack(spacing: 10) {
                    ForEach(WritingTheme.allCases) { theme in
                        Button { preferences.selectTheme(theme) } label: {
                            VStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 6).fill(Color(hex: theme.surface))
                                    .overlay { Text("Aa").font(.custom("IowanOldStyle-Roman", size: 20)).foregroundStyle(Color(hex: theme.text)) }
                                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(Color(hex: theme.accent).opacity(preferences.value.theme == theme ? 1 : 0.15), lineWidth: preferences.value.theme == theme ? 2 : 1) }
                                    .frame(height: 50)
                                Text(theme.label).font(.system(size: 10))
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.plain)
                    }
                }
            }
            SettingsSection(L10n.text("背景图片")) {
                Picker(L10n.text("背景"), selection: $preferences.value.wallpaper) { ForEach(WallpaperKind.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented).labelsHidden()
                Button(action: preferences.chooseWallpaper) {
                    Label(preferences.value.customWallpaperPath == nil ? L10n.text("选择自己的图片…") : L10n.text("更换自己的图片…"), systemImage: "photo.on.rectangle").font(.system(size: 11))
                }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                if preferences.value.wallpaper != .none {
                    Picker(L10n.text("铺放方式"), selection: $preferences.value.fit) { ForEach(WallpaperFit.allCases) { Text($0.label).tag($0) } }.font(.system(size: 11))
                    SettingsSlider(L10n.text("缩放"), value: $preferences.value.scale, range: 0.5...3, suffix: "×", decimals: 2)
                    SettingsSlider(L10n.text("水平位置"), value: $preferences.value.positionX, range: 0...1, decimals: 2)
                    SettingsSlider(L10n.text("垂直位置"), value: $preferences.value.positionY, range: 0...1, decimals: 2)
                    SettingsSlider(L10n.text("图片不透明度"), value: $preferences.value.wallpaperOpacity, range: 0...1, decimals: 2)
                    SettingsSlider(L10n.text("背景模糊"), value: $preferences.value.blur, range: 0...40, suffix: "px")
                    SettingsSlider(L10n.text("色彩饱和度"), value: $preferences.value.saturation, range: 0...2, decimals: 2)
                }
            }
            SettingsSection(L10n.text("底色与遮罩")) {
                ColorPicker(L10n.text("背景底色"), selection: colorBinding(\.backgroundColor), supportsOpacity: false).font(.system(size: 11))
                ColorPicker(L10n.text("遮罩颜色"), selection: colorBinding(\.overlayColor), supportsOpacity: false).font(.system(size: 11))
                SettingsSlider(L10n.text("遮罩浓度"), value: $preferences.value.overlayOpacity, range: 0...1, decimals: 2)
            }
            SettingsSection(L10n.text("纸面与侧栏")) {
                SettingsSlider(L10n.text("纸面不透明度"), value: $preferences.value.paperOpacity, range: 0.25...1, decimals: 2)
                SettingsSlider(L10n.text("侧栏不透明度"), value: $preferences.value.sidebarOpacity, range: 0.35...1, decimals: 2)
            }
        }
    }

    private func colorBinding(_ key: WritableKeyPath<AppearancePreferences, String>) -> Binding<Color> {
        Binding(get: { Color(hex: preferences.value[keyPath: key]) }, set: { preferences.value[keyPath: key] = $0.rgbHex })
    }
}
