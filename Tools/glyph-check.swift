import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit
import Vision

// 把手寫數字渲染成 PNG，再用 Vision 讀回來。
// 這是「我畫的字到底看不看得懂」唯一客觀的檢查方式。
//
//   swiftc -enable-bare-slash-regex FuelCost/Services/FuelPumpParser.swift \
//          FuelCost/Services/PumpTextRecognizer.swift FuelCost/World/MarkerGlyphs.swift \
//          Tools/glyph-check.swift -o /tmp/glyphcheck && /tmp/glyphcheck

@main
enum GlyphCheck {

    static func main() {
        let cases: [(text: String, height: CGFloat, color: (CGFloat, CGFloat, CGFloat))] = [
            ("0123456789", 220, (0.09, 0.09, 0.10)),
            ("13.4", 340, (0.85, 0.20, 0.16)),      // 紅麥克筆，畫面上真正的大小
            ("2.34", 200, (0.85, 0.20, 0.16)),
            ("45,210", 240, (0.09, 0.09, 0.10)),
            ("13.55", 260, (0.85, 0.20, 0.16)),
            ("95", 260, (0.85, 0.20, 0.16)),
        ]

        var failures = 0
        let outputDirectory = URL(fileURLWithPath: "/tmp/marker-glyphs")
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for testCase in cases {
            let expectedDigits = testCase.text.filter(\.isNumber)
            guard let url = render(testCase.text, height: testCase.height, color: testCase.color, into: outputDirectory) else {
                print("FAIL 畫不出來：\(testCase.text)")
                failures += 1
                continue
            }

            guard let image = NSImage(contentsOf: url),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                print("FAIL 讀不回自己畫的檔：\(url.path)")
                failures += 1
                continue
            }

            let lines = (try? PumpTextRecognizer.readLines(in: cgImage)) ?? []
            let readDigits = lines.joined().filter(\.isNumber)
            let passed = readDigits == expectedDigits
            let mark = passed ? "ok  " : "FAIL"
            print("\(mark) 寫「\(testCase.text)」→ Vision 讀到「\(lines.joined(separator: " "))」")
            if !passed { failures += 1 }
        }

        print("")
        print(failures == 0 ? "手寫數字全部讀得回來" : "有 \(failures) 個字沒被讀對")
        exit(failures == 0 ? 0 : 1)
    }

    private static func render(
        _ text: String,
        height: CGFloat,
        color: (CGFloat, CGFloat, CGFloat),
        into directory: URL
    ) -> URL? {
        let width = MarkerGlyphs.width(of: text, height: height)
        let padding = height * 0.5
        let canvasWidth = Int(ceil(width + padding * 2))
        let canvasHeight = Int(ceil(height + padding * 2))

        guard let context = CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 白紙
        context.setFillColor(CGColor(srgbRed: 0.97, green: 0.96, blue: 0.93, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

        // MarkerGlyphs 的 y 由上而下；CoreGraphics 的 y 由下而上。
        context.translateBy(x: 0, y: CGFloat(canvasHeight))
        context.scaleBy(x: 1, y: -1)

        let path = MarkerGlyphs.path(for: text, height: height, seed: 7)
        context.setStrokeColor(CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1))
        context.setLineWidth(height * MarkerGlyphs.strokeWidthRatio)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        var transform = CGAffineTransform(translationX: padding, y: padding)
        guard let shifted = path.copy(using: &transform) else { return nil }
        context.addPath(shifted)
        context.strokePath()

        guard let cgImage = context.makeImage() else { return nil }
        let url = directory.appendingPathComponent("\(text.replacingOccurrences(of: ",", with: "_")).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination) ? url : nil
    }
}
