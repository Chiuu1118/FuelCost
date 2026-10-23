import Foundation
import UIKit
import Vision

/// 一次辨識的結果。跟 PumpTextRecognizer 的形狀一樣，只是換成 app 裡用的名字。
typealias FuelScanOutcome = PumpTextRecognizer.Outcome

enum ReceiptScannerError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "這張照片讀不出來，換一張，或直接手動輸入。"
        }
    }
}

/// app 這一側的包裝：把 UIImage 轉成 CoreGraphics 影像，其餘交給 PumpTextRecognizer。
enum ReceiptScanner {

    /// 這個方法會同步跑完辨識，請從主執行緒以外的地方呼叫。
    static func scan(image: UIImage) throws -> FuelScanOutcome {
        guard let cgImage = image.cgImage else { throw ReceiptScannerError.unreadableImage }
        return try PumpTextRecognizer.scan(cgImage, orientation: cgImageOrientation(from: image.imageOrientation))
    }

    private static func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
