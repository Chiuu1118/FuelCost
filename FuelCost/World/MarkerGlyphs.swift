import CoreGraphics
import Foundation

/// 麥克筆單線數字：這個世界自己的展示字。
///
/// 為什麼要自己畫：小店標價牌上的價格是手寫的，那不是任何一套字型。
/// craft floor 也不准拿系統字當自有世界的展示字，而 iOS 上 UI 文字又必須是 SF。
/// 所以價格自己畫，其餘交給系統。
///
/// 這一支只依賴 CoreGraphics，所以同一份幾何可以在 macOS 命令列上
/// 渲染成 PNG、再讓 Vision 讀回來驗證「寫得夠清楚」。
enum MarkerGlyphs {

    // MARK: - 筆畫

    struct Stroke {
        enum Segment {
            case move(CGPoint)
            case line(CGPoint)
            case curve(to: CGPoint, c1: CGPoint, c2: CGPoint)
        }

        var segments: [Segment]
    }

    /// 座標系：x 由左而右、y 由上而下，數字高度正規化為 1。
    static func strokes(for character: Character) -> [Stroke] {
        switch character {
        case "0":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.31, y: 0.06)),
                .curve(to: CGPoint(x: 0.31, y: 0.94), c1: CGPoint(x: 0.06, y: 0.12), c2: CGPoint(x: 0.06, y: 0.88)),
                .curve(to: CGPoint(x: 0.31, y: 0.06), c1: CGPoint(x: 0.56, y: 0.94), c2: CGPoint(x: 0.56, y: 0.12)),
            ])]

        case "1":
            return [
                Stroke(segments: [
                    .move(CGPoint(x: 0.14, y: 0.26)),
                    .curve(to: CGPoint(x: 0.33, y: 0.06), c1: CGPoint(x: 0.22, y: 0.18), c2: CGPoint(x: 0.28, y: 0.10)),
                ]),
                Stroke(segments: [
                    .move(CGPoint(x: 0.33, y: 0.06)),
                    .line(CGPoint(x: 0.33, y: 0.94)),
                ]),
                Stroke(segments: [
                    .move(CGPoint(x: 0.13, y: 0.94)),
                    .line(CGPoint(x: 0.55, y: 0.94)),
                ]),
            ]

        case "2":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.08, y: 0.26)),
                .curve(to: CGPoint(x: 0.54, y: 0.26), c1: CGPoint(x: 0.06, y: 0.04), c2: CGPoint(x: 0.56, y: 0.02)),
                .curve(to: CGPoint(x: 0.08, y: 0.92), c1: CGPoint(x: 0.52, y: 0.50), c2: CGPoint(x: 0.28, y: 0.66)),
                .line(CGPoint(x: 0.58, y: 0.92)),
            ])]

        case "3":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.10, y: 0.18)),
                .curve(to: CGPoint(x: 0.48, y: 0.30), c1: CGPoint(x: 0.16, y: 0.00), c2: CGPoint(x: 0.58, y: 0.02)),
                .curve(to: CGPoint(x: 0.26, y: 0.52), c1: CGPoint(x: 0.40, y: 0.50), c2: CGPoint(x: 0.30, y: 0.48)),
                .curve(to: CGPoint(x: 0.56, y: 0.72), c1: CGPoint(x: 0.22, y: 0.56), c2: CGPoint(x: 0.56, y: 0.58)),
                .curve(to: CGPoint(x: 0.12, y: 0.88), c1: CGPoint(x: 0.56, y: 0.86), c2: CGPoint(x: 0.30, y: 0.98)),
            ])]

        case "4":
            return [
                Stroke(segments: [
                    .move(CGPoint(x: 0.44, y: 0.06)),
                    .line(CGPoint(x: 0.08, y: 0.66)),
                    .line(CGPoint(x: 0.58, y: 0.66)),
                ]),
                Stroke(segments: [
                    .move(CGPoint(x: 0.44, y: 0.06)),
                    .line(CGPoint(x: 0.44, y: 0.94)),
                ]),
            ]

        case "5":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.50, y: 0.08)),
                .line(CGPoint(x: 0.16, y: 0.08)),
                .line(CGPoint(x: 0.13, y: 0.42)),
                .curve(to: CGPoint(x: 0.46, y: 0.44), c1: CGPoint(x: 0.24, y: 0.34), c2: CGPoint(x: 0.42, y: 0.32)),
                .curve(to: CGPoint(x: 0.20, y: 0.88), c1: CGPoint(x: 0.56, y: 0.58), c2: CGPoint(x: 0.56, y: 0.84)),
                .curve(to: CGPoint(x: 0.08, y: 0.82), c1: CGPoint(x: 0.12, y: 0.90), c2: CGPoint(x: 0.08, y: 0.86)),
            ])]

        case "6":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.50, y: 0.07)),
                .curve(to: CGPoint(x: 0.10, y: 0.50), c1: CGPoint(x: 0.26, y: 0.06), c2: CGPoint(x: 0.10, y: 0.24)),
                .curve(to: CGPoint(x: 0.36, y: 0.95), c1: CGPoint(x: 0.10, y: 0.80), c2: CGPoint(x: 0.20, y: 0.95)),
                .curve(to: CGPoint(x: 0.11, y: 0.60), c1: CGPoint(x: 0.54, y: 0.94), c2: CGPoint(x: 0.52, y: 0.62)),
            ])]

        case "7":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.10, y: 0.10)),
                .line(CGPoint(x: 0.56, y: 0.08)),
                .line(CGPoint(x: 0.26, y: 0.94)),
            ])]

        case "8":
            return [
                Stroke(segments: [
                    .move(CGPoint(x: 0.33, y: 0.48)),
                    .curve(to: CGPoint(x: 0.33, y: 0.10), c1: CGPoint(x: 0.12, y: 0.48), c2: CGPoint(x: 0.12, y: 0.10)),
                    .curve(to: CGPoint(x: 0.33, y: 0.48), c1: CGPoint(x: 0.54, y: 0.10), c2: CGPoint(x: 0.54, y: 0.48)),
                ]),
                Stroke(segments: [
                    .move(CGPoint(x: 0.33, y: 0.48)),
                    .curve(to: CGPoint(x: 0.33, y: 0.92), c1: CGPoint(x: 0.08, y: 0.48), c2: CGPoint(x: 0.08, y: 0.92)),
                    .curve(to: CGPoint(x: 0.33, y: 0.48), c1: CGPoint(x: 0.58, y: 0.92), c2: CGPoint(x: 0.58, y: 0.48)),
                ]),
            ]

        case "9":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.12, y: 0.93)),
                .curve(to: CGPoint(x: 0.52, y: 0.50), c1: CGPoint(x: 0.36, y: 0.94), c2: CGPoint(x: 0.52, y: 0.76)),
                .curve(to: CGPoint(x: 0.26, y: 0.05), c1: CGPoint(x: 0.52, y: 0.20), c2: CGPoint(x: 0.42, y: 0.05)),
                .curve(to: CGPoint(x: 0.51, y: 0.40), c1: CGPoint(x: 0.08, y: 0.08), c2: CGPoint(x: 0.10, y: 0.38)),
            ])]

        case ".":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.10, y: 0.88)),
                .line(CGPoint(x: 0.11, y: 0.885)),
            ])]

        case ",":
            return [Stroke(segments: [
                .move(CGPoint(x: 0.15, y: 0.82)),
                .curve(to: CGPoint(x: 0.06, y: 1.02), c1: CGPoint(x: 0.16, y: 0.90), c2: CGPoint(x: 0.12, y: 0.97)),
            ])]

        default:
            return []
        }
    }

    /// 每個字的寬度（正規化到數字高度 1）。
    static func width(of character: Character) -> CGFloat {
        switch character {
        case ".", ",": return 0.26
        default: return strokes(for: character).isEmpty ? 0.32 : 0.62
        }
    }

    private static let letterGap: CGFloat = 0.10

    /// 一整串字的寬度，畫面上排版要用。
    static func width(of text: String, height: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        var total: CGFloat = 0
        for character in text {
            total += width(of: character) + letterGap
        }
        return (total - letterGap) * height
    }

    /// 把一串字組成單一路徑。同一個 seed 永遠得到同一種抖動——
    /// 手寫感不該是每次重畫都不一樣的雜訊。
    static func path(for text: String, height: CGFloat, seed: Int = 0) -> CGPath {
        let path = CGMutablePath()
        var penX: CGFloat = 0

        for (index, character) in text.enumerated() {
            let glyphStrokes = strokes(for: character)
            let glyphWidth = width(of: character)

            for (strokeIndex, stroke) in glyphStrokes.enumerated() {
                var previous = CGPoint.zero
                for (segmentIndex, segment) in stroke.segments.enumerated() {
                    let jitter = Jitter(seed: seed, glyph: index, stroke: strokeIndex, segment: segmentIndex)

                    switch segment {
                    case .move(let point):
                        let p = jitter.apply(point, penX: penX, glyphWidth: glyphWidth, height: height)
                        path.move(to: p)
                        previous = p

                    case .line(let point):
                        let p = jitter.apply(point, penX: penX, glyphWidth: glyphWidth, height: height)
                        path.addLine(to: p)
                        previous = p

                    case .curve(let to, let c1, let c2):
                        let p1 = jitter.apply(c1, penX: penX, glyphWidth: glyphWidth, height: height)
                        let p2 = jitter.apply(c2, penX: penX, glyphWidth: glyphWidth, height: height)
                        let p3 = jitter.apply(to, penX: penX, glyphWidth: glyphWidth, height: height)
                        path.addCurve(to: p3, control1: p1, control2: p2)
                        previous = p3
                    }
                }
                _ = previous
            }

            penX += (glyphWidth + letterGap) * height
        }

        return path
    }

    /// 落筆的抖動：幅度很小（高度的一百分之一），只是讓線不像機器畫的。
    private struct Jitter {
        let seed: Int
        let glyph: Int
        let stroke: Int
        let segment: Int

        func apply(_ point: CGPoint, penX: CGFloat, glyphWidth: CGFloat, height: CGFloat) -> CGPoint {
            let amplitude = height * 0.010
            let x = penX + point.x * height + offset(salt: 1) * amplitude
            let y = point.y * height + offset(salt: 2) * amplitude
            return CGPoint(x: x, y: y)
        }

        /// 由 seed 與位置決定的偽隨機值，範圍 -1…1。
        private func offset(salt: Int) -> CGFloat {
            var value = UInt64(bitPattern: Int64(seed &* 2_654_435_761))
            value ^= UInt64(glyph &* 40_503)
            value ^= UInt64(stroke &* 2_246_822_519)
            value ^= UInt64(segment &* 326_648_861)
            value ^= UInt64(salt &* 69_621)
            value ^= value >> 33
            value = value &* 0xff51afd7ed558ccd
            value ^= value >> 33
            let unit = CGFloat(value % 1000) / 1000.0
            return unit * 2 - 1
        }
    }

    /// 麥克筆的筆畫粗細（相對字高）。
    static let strokeWidthRatio: CGFloat = 0.145
}
