import Foundation
import UIKit

/// 油機照片存在 app 自己的容器裡，不進相簿、不上傳，刪紀錄時一起刪掉。
enum PhotoStore {

    private static let folderName = "Photos"

    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static func url(for fileName: String) throws -> URL {
        try directory().appendingPathComponent(fileName)
    }

    /// 存成 JPEG，回傳檔名。長邊縮到 2000 px，免得容器被幾張原圖撐爆。
    @discardableResult
    static func save(_ image: UIImage) throws -> String {
        let resized = downscaled(image, maxDimension: 2000)
        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let fileName = UUID().uuidString + ".jpg"
        try data.write(to: try url(for: fileName), options: .atomic)
        return fileName
    }

    static func load(_ fileName: String) -> UIImage? {
        guard let fileURL = try? url(for: fileName) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    static func delete(_ fileName: String) {
        guard let fileURL = try? url(for: fileName) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return image }

        let scale = maxDimension / longestSide
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
