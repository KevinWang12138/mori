import SwiftUI

struct AppearancePreview: View {
    @EnvironmentObject private var preferences: PreferencesStore
    private var value: AppearancePreferences { preferences.value }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("写作环境预览")).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            ZStack {
                WallpaperView(preferences: value)
                VStack(alignment: .leading, spacing: 22) {
                    Text(L10n.text("留一片安静\n给文字。")).font(.custom(previewFont, size: 29)).lineSpacing(5)
                    Rectangle().fill(Color(hex: value.theme.accent)).frame(width: 28, height: 2)
                    Text(L10n.text("晨光经过窗沿，落在还没写完的句子上。\n\n从一个想法开始，慢慢写成一篇文章。"))
                        .font(.custom(previewFont, size: min(18, value.fontSize * 0.8))).lineSpacing(value.lineHeight * 3)
                    Spacer()
                    Text("MORI / A QUIET PLACE TO WRITE").font(.system(size: 7, design: .monospaced)).tracking(1.8).foregroundStyle(.secondary)
                }
                .foregroundStyle(Color(hex: value.theme.text)).padding(30)
                .frame(width: 290, height: 388, alignment: .topLeading)
                .background(Color(hex: value.theme.surface).opacity(value.paperOpacity), in: RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.03), radius: 12, y: 4)
            }.frame(maxWidth: .infinity).frame(height: 460).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.08), lineWidth: 1) }
            Text(L10n.text("更改会即时应用到文章。主题文件包含外观参数与 CSS，自选图片保留在本机。")).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
        }.allowsHitTesting(false)
    }
    private var previewFont: String { switch value.font { case .editorial: return "IowanOldStyle-Roman"; case .system: return "PingFangSC-Regular"; case .song: return "SongtiSC-Regular" } }
}
