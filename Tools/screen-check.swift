import Foundation
import AppKit
import Vision

// 把模擬器截圖上的字讀回來。
//
// 這是「畫面到底長什麼樣」在沒有視覺模型時唯一客觀的檢查方式：
// 截圖裡該出現的字有沒有出現、不該出現的有沒有跑出來。
//
//   swiftc -enable-bare-slash-regex FuelCost/Services/FuelPumpParser.swift \
//          FuelCost/Services/PumpTextRecognizer.swift \
//          Tools/screen-check.swift -o /tmp/screencheck
//   /tmp/screencheck dump 圖片.png
//   /tmp/screencheck expect 圖片.png "累計平均油耗" "13.55"

@main
enum ScreenCheck {
    static func main() {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let mode = arguments.first else {
            print("用法：screencheck dump|expect <圖片> [要出現的字…]")
            exit(2)
        }
        arguments.removeFirst()

        switch mode {
        case "dump":
            for path in arguments {
                print("── \(path)")
                for line in lines(in: path) { print("   \(line)") }
            }

        case "expect":
            guard let path = arguments.first else { exit(2) }
            let expected = Array(arguments.dropFirst())
            let text = lines(in: path).joined(separator: "\n")
            var missing: [String] = []
            for needle in expected {
                let found = text.contains(needle)
                print(found ? "   ok   \(needle)" : "   MISS \(needle)")
                if !found { missing.append(needle) }
            }
            if !missing.isEmpty {
                print("   畫面全文：\(text.replacingOccurrences(of: "\n", with: " / "))")
                exit(1)
            }

        default:
            print("不認識的模式：\(mode)")
            exit(2)
        }
    }

    private static func lines(in path: String) -> [String] {
        guard let image = NSImage(contentsOfFile: path),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ["（讀不到這張圖）"]
        }
        return (try? PumpTextRecognizer.readLines(in: cgImage)) ?? []
    }
}
