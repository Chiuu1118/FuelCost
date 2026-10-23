import SwiftUI

/// 麥克筆寫的一串數字。畫面上每一個「價格」都用它。
///
/// 這一支是 Shape 而不是 Canvas，因為 Shape 會把 progress 內插——
/// 落筆的動畫才會是筆畫一筆一筆長出來，而不是整串淡入。
struct MarkerNumber: View {
    let text: String
    let size: CGFloat
    var color: Color = Marker.red
    var seed: Int = 0

    /// 只在「值得看它被寫出來」的地方開：剛存好一筆、第一次看到平均值。
    /// 邊打里程邊更新的數字不該一直重寫，那是噪音。
    var writesOnAppear: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1
    @State private var progress: Double

    init(text: String, size: CGFloat, color: Color = Marker.red, seed: Int = 0, writesOnAppear: Bool = false) {
        self.text = text
        self.size = size
        self.color = color
        self.seed = seed
        self.writesOnAppear = writesOnAppear
        _progress = State(initialValue: writesOnAppear ? 0 : 1)
    }

    private var glyphHeight: CGFloat { size * scale }

    var body: some View {
        MarkerStrokeShape(text: text, height: glyphHeight, seed: seed, progress: progress)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: glyphHeight * MarkerGlyphs.strokeWidthRatio,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: MarkerGlyphs.width(of: text, height: glyphHeight), height: glyphHeight * 1.16)
            .accessibilityElement()
            .accessibilityLabel(Text(text))
            .onAppear {
                guard writesOnAppear, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.55)) { progress = 1 }
            }
    }
}

/// 單一筆畫的形狀。progress 就是筆畫走到哪裡。
private struct MarkerStrokeShape: Shape {
    let text: String
    let height: CGFloat
    let seed: Int
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // trimmedPath 在 SwiftUI 的 Path 上，不在 CGPath 上。
        let full = Path(MarkerGlyphs.path(for: text, height: height, seed: seed))
        guard progress < 1 else { return full }
        return full.trimmedPath(from: 0, to: max(0, progress))
    }
}

/// 一行字裡混排版面用的數字：`13.55 km/L` 這種。
/// 數字自己畫，單位交給 SF——世界只借用版面，不借用文字。
struct MarkerMeasurement: View {
    let value: String
    let unit: String
    var size: CGFloat = 34
    var color: Color = Marker.red
    var seed: Int = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            MarkerNumber(text: value, size: size, color: color, seed: seed)
            Text(unit)
                .font(.system(size: max(11, size * 0.32), weight: .bold))
                .foregroundStyle(color)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(value) \(unit)"))
    }
}

/// 有值就用麥克筆寫上去，沒有值就誠實留一條破折號。
/// 這個世界不會為了畫面好看而填一個假的 0。
struct MarkerValue: View {
    let value: Double?
    var unit: String?
    var size: CGFloat = 34
    var color: Color = Marker.red
    var seed: Int = 0
    var format: (Double) -> String = DisplayFormat.integer

    var body: some View {
        if let value {
            let text = format(value)
            if let unit {
                MarkerMeasurement(value: text, unit: unit, size: size, color: color, seed: seed)
            } else {
                MarkerNumber(text: text, size: size, color: color, seed: seed)
            }
        } else {
            Text("—")
                .font(.system(size: size * 0.62, weight: .bold))
                .foregroundStyle(Marker.faded)
                .accessibilityLabel(Text("沒有資料"))
        }
    }
}
