import SwiftUI

// MARK: - 紙

/// 桌面：貼著卡紙的那張桌子。兩道很淡的光，不用圖片，深色模式自己轉暗。
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Marker.paper
            RadialGradient(
                colors: [Color.white.opacity(0.55), .clear],
                center: .init(x: 0.15, y: -0.05),
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [Color.black.opacity(0.05), .clear],
                center: .init(x: 1.05, y: 0.95),
                startRadius: 0,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - 卡紙

/// 白卡壓在紙上：一點點影子、一條細邊、微微歪。
/// 歪的角度由呼叫端給，而且必須是固定的值——每次重畫都在抖就不是手寫，是雜訊。
private struct CardSurface: ViewModifier {
    var rotation: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Marker.card)
                    .shadow(color: Marker.cardShadow, radius: 5, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Marker.hair, lineWidth: 1)
            )
            .rotationEffect(.degrees(rotation))
    }
}

extension View {
    /// 變成一張卡紙。
    func cardSurface(rotation: Double = 0) -> some View {
        modifier(CardSurface(rotation: rotation))
    }
}

// MARK: - 手繪線

/// 由 seed 決定的固定抖動。同一個 seed 永遠得到同一條線。
func markerWobble(seed: Int) -> CGFloat {
    var value = UInt64(bitPattern: Int64(seed &* 2_246_822_519))
    value ^= value >> 31
    value = value &* 0xff51afd7ed558ccd
    value ^= value >> 33
    return CGFloat(value % 1000) / 1000.0 * 2 - 1
}

/// 手繪的線。麥克筆畫的線從來不是直的，也不會剛好水平。
struct HandLine: Shape {
    var seed: Int = 0
    var slope: CGFloat = 0.006
    var amplitude: CGFloat = 1.6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.minY + rect.height / 2)
        let end = CGPoint(x: rect.maxX, y: rect.minY + rect.height / 2 + rect.height * slope * 8)

        path.move(to: start)
        let steps = 4
        var previous = start
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            let wave = markerWobble(seed: seed &+ step) * amplitude
            let control = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2 + wave)
            path.addQuadCurve(to: point, control: control)
            previous = point
        }
        return path
    }
}

/// 麥克筆的雙底線：標價牌上「這個數字是重點」的寫法。
struct HandUnderline: View {
    var color: Color = Marker.red
    var seed: Int = 0
    var lineWidth: CGFloat = 2.6

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HandLine(seed: seed, amplitude: 1.5)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(height: 4)
            HandLine(seed: seed &+ 91, amplitude: 1.2)
                .stroke(color.opacity(0.75), style: StrokeStyle(lineWidth: lineWidth * 0.8, lineCap: .round))
                .frame(height: 3)
                .padding(.trailing, 46)
        }
        .accessibilityHidden(true)
    }
}

/// 紅筆劃掉：這個數字被改過了，或是這一筆不算。
/// 這個世界用劃掉表示「不要看這個」，不是靠把字變灰。
struct HandStrike: View {
    var color: Color = Marker.red
    var seed: Int = 0
    var lineWidth: CGFloat = 2.6

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HandLine(seed: seed, slope: 0.0, amplitude: 2.0)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: proxy.size.width * 0.98, height: proxy.size.height * 0.34)
                    .rotationEffect(.degrees(-7))
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.42)
                HandLine(seed: seed &+ 37, slope: 0.0, amplitude: 1.6)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth * 0.85, lineCap: .round))
                    .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.22)
                    .rotationEffect(.degrees(4))
                    .position(x: proxy.size.width * 0.46, y: proxy.size.height * 0.60)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 藍筆的註記

/// 藍筆寫的小標籤，微微歪，像隨手貼上去的。
struct MarkerStamp: View {
    let text: String
    var color: Color = Marker.blue
    var rotation: Double = -1.4

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(color.opacity(0.7), lineWidth: 1.4)
            )
            .rotationEffect(.degrees(rotation))
    }
}

/// 欄位標籤：藍筆的語氣，字距放寬，小字但看得清楚。
struct FieldLabel: View {
    private let text: String
    private let color: Color

    init(_ text: String, color: Color = Marker.faded) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

// MARK: - 狀態

/// 一句話講清楚這筆帳可不可信。紅筆只在真的有事時出現。
struct StateNote: View {
    let symbol: String
    let text: String
    var tone: Tone = .note

    enum Tone {
        case note      // 藍筆：一切正常
        case pending   // 灰筆：資料還不夠
        case problem   // 紅筆：有東西要處理

        var color: Color {
            switch self {
            case .note: return Marker.blue
            case .pending: return Marker.faded
            case .problem: return Marker.red
            }
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tone.color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 主要動作

/// 紅筆塗滿的卡：這個世界裡最強的動作。
/// 刻意做成整整一張卡而不是膠囊——它是標價牌，不是按鈕。
struct MarkerActionButton: View {
    let title: String
    var systemImage: String = "camera.viewfinder"
    var fill: Color = Marker.red
    var foreground: Color = Marker.onRed
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .bold))
                Text(title)
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(fill)
            )
        }
        .buttonStyle(MarkerPressStyle())
    }
}

/// 按下去像壓一張卡：縮一點、暗一點。不用彈跳。
struct MarkerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// 次要動作：藍筆框起來的卡。
struct MarkerSecondaryButton: View {
    let title: String
    var systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Marker.blue)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Marker.blue.opacity(0.55), lineWidth: 1.5)
            )
        }
        .buttonStyle(MarkerPressStyle())
    }
}
