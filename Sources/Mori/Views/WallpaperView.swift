import SwiftUI

private enum WallpaperCache {
    static let images = NSCache<NSString, NSImage>()
    static func image(at path: String) -> NSImage? {
        if let image = images.object(forKey: path as NSString) { return image }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        images.setObject(image, forKey: path as NSString); return image
    }
}

struct WallpaperView: View {
    var preferences: AppearancePreferences
    private var image: NSImage? {
        switch preferences.wallpaper {
        case .none: return nil
        case .forest: return WallpaperCache.image(at: AppPaths.resources.appendingPathComponent("Wallpapers/forest-lake.png").path)
        case .custom: return preferences.customWallpaperPath.flatMap { WallpaperCache.image(at: $0) }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color(hex: preferences.backgroundColor)
                if let image {
                    wallpaper(image, in: geometry.size)
                        .saturation(preferences.saturation).blur(radius: preferences.blur)
                        .opacity(preferences.wallpaperOpacity)
                }
                Color(hex: preferences.overlayColor).opacity(preferences.wallpaper == .none ? 0 : preferences.overlayOpacity)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.ignoresSafeArea()
    }

    @ViewBuilder
    private func wallpaper(_ image: NSImage, in size: CGSize) -> some View {
        if preferences.fit == .tile {
            Image(nsImage: image).resizable(resizingMode: .tile)
                .frame(width: size.width / preferences.scale + image.size.width, height: size.height / preferences.scale + image.size.height)
                .scaleEffect(preferences.scale, anchor: .topLeading)
                .offset(x: -image.size.width * preferences.positionX, y: -image.size.height * preferences.positionY)
        } else {
            let ratio = preferences.fit == .cover ? max(size.width / image.size.width, size.height / image.size.height) : min(size.width / image.size.width, size.height / image.size.height)
            let width = image.size.width * ratio * preferences.scale
            let height = image.size.height * ratio * preferences.scale
            Image(nsImage: image).resizable().frame(width: width, height: height)
                .offset(x: (size.width - width) * preferences.positionX, y: (size.height - height) * preferences.positionY)
        }
    }
}
