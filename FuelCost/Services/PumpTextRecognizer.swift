import Foundation
import Vision
import CoreImage

/// 油機文字辨識的核心：只依賴 Vision 與 CoreImage，不碰 UIKit。
///
/// 抽出來的理由很實際：同一份程式可以在 macOS 命令列上對測試照片跑一遍，
/// 不必為了驗證辨識而先啟動模擬器。
enum PumpTextRecognizer {

    /// 一次辨識的結果：解析出來的三個數字，加上原始辨識文字（讓使用者自己核對）。
    struct Outcome {
        var reading: FuelPumpReading
        var lines: [String]

        var text: String { lines.joined(separator: "\n") }
    }

    enum Failure: LocalizedError {
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .noTextFound: return "照片裡找不到文字。光線不夠或太模糊，換一張或直接手動輸入。"
            }
        }
    }

    /// 辨識 + 解析。第一次讀不出東西時，會拉高對比再讀一次。
    static func scan(_ cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) throws -> Outcome {
        let first = try readLines(in: cgImage, orientation: orientation)
        let firstReading = FuelPumpParser.parse(first.joined(separator: "\n"))

        if first.isEmpty || firstReading.isEmpty,
           let boosted = boosted(cgImage),
           let second = try? readLines(in: boosted, orientation: orientation),
           !second.isEmpty {
            let secondReading = FuelPumpParser.parse(second.joined(separator: "\n"))
            if !secondReading.isEmpty || first.isEmpty {
                return Outcome(reading: secondReading, lines: second)
            }
        }

        guard !first.isEmpty else { throw Failure.noTextFound }
        return Outcome(reading: firstReading, lines: first)
    }

    /// 一行一行讀。順序按位置重排，因為加油機的字塊常常上下跳。
    static func readLines(in cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // 數字不要被語言模型自動「修正」成別的字。
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hant", "en-US"]
        request.customWords = ["公升", "金額", "單價", "加油量", "總計", "無鉛", "九五", "油錢", "元", "L"]
        request.minimumTextHeight = 0.008

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])

        let observations: [VNRecognizedTextObservation] = request.results ?? []
        guard !observations.isEmpty else { return [] }

        // 位置在 observation 上，文字本身沒有，所以先排 observation 再取字。
        let ordered = observations.sorted { (lhs: VNRecognizedTextObservation, rhs: VNRecognizedTextObservation) -> Bool in
            let leftMidY = lhs.boundingBox.midY
            let rightMidY = rhs.boundingBox.midY
            if abs(leftMidY - rightMidY) > 0.02 { return leftMidY > rightMidY }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        return ordered.compactMap { $0.topCandidates(1).first?.string }
    }

    /// 灰階 + 拉高對比，讓 LED 數字從背景跳出來。
    static func boosted(_ cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let mono = input.applyingFilter("CIPhotoEffectMono")
        let contrast = mono.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 2.1,
            kCIInputBrightnessKey: 0.02,
        ])
        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(contrast, from: input.extent)
    }
}
