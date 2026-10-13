import AppKit
import UniformTypeIdentifiers

enum ImageImportService {
    // ===== 把图片存到文章旁边，Markdown 使用可移植的相对路径 =====
    static func importImage(data: Data, name: String, articleURL: URL) throws -> String {
        guard data.count <= 25 * 1024 * 1024, let image = NSImage(data: data), image.size.width > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let originalExtension = URL(fileURLWithPath: name).pathExtension.lowercased()
        let known = Set(["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff"])
        var payload = data
        var fileExtension = known.contains(originalExtension) ? originalExtension : "png"
        if fileExtension == "heic" || fileExtension == "tiff" || !known.contains(originalExtension) {
            guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileReadCorruptFile) }
            payload = png; fileExtension = "png"
        }
        let directory = articleURL.deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let basename = articleURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "[^\\p{L}\\p{N}_-]", with: "-", options: .regularExpression)
        let filename = String(basename.prefix(40)) + "-" + UUID().uuidString.prefix(8) + "." + fileExtension
        try payload.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return "assets/" + filename
    }
}
