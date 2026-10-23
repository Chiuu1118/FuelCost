import Foundation
import AppKit
import Vision

// 在命令列上對測試照片跑一次真正的 Vision 辨識，用的是 app 裡同一份核心。
//   swiftc FuelCost/Services/FuelPumpParser.swift FuelCost/Services/PumpTextRecognizer.swift \
//          Tools/ocr-check.swift -o /tmp/ocrcheck && /tmp/ocrcheck Tools/fixtures/receipt.png Tools/fixtures/pump-led.png

@main
enum OcrCheck {
    static func main() {
        let paths = Array(CommandLine.arguments.dropFirst())
        guard !paths.isEmpty else {
            print("用法：ocrcheck <圖片路徑>...")
            exit(2)
        }

        var failures = 0

        for path in paths {
            print("── \(path)")
            guard let image = NSImage(contentsOfFile: path),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                print("   讀不到這張圖")
                failures += 1
                continue
            }

            do {
                let outcome = try PumpTextRecognizer.scan(cgImage)
                for line in outcome.lines {
                    print("   \(line)")
                }

                let reading = outcome.reading
                print("   → 金額 \(show(reading.amountNTD)) / 公升 \(show(reading.liters)) / 單價 \(show(reading.unitPriceNTD)) [\(reading.confidence.rawValue)]")
                for warning in reading.warnings { print("   ⚠️ \(warning)") }

                let name = (path as NSString).lastPathComponent
                switch name {
                case "receipt.png", "pump-led.png":
                    failures += check("\(name)：金額 1,024", close(reading.amountNTD, 1024))
                    failures += check("\(name)：公升 32.40", close(reading.liters, 32.40))
                default:
                    print("   （沒有預期值，只印出來看）")
                }
            } catch {
                print("   辨識失敗：\(error.localizedDescription)")
                failures += 1
            }
            print("")
        }

        print(failures == 0 ? "辨識檢查全部通過" : "有 \(failures) 項沒過")
        exit(failures == 0 ? 0 : 1)
    }

    private static func show(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    private static func close(_ value: Double?, _ expected: Double, tolerance: Double = 0.011) -> Bool {
        guard let value else { return false }
        return abs(value - expected) <= tolerance
    }

    private static func check(_ label: String, _ passed: Bool) -> Int {
        print(passed ? "   ok   \(label)" : "   FAIL \(label)")
        return passed ? 0 : 1
    }
}
