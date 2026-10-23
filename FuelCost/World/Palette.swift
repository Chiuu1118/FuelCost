import SwiftUI
import UIKit

/// 這個世界的顏色：小店的白卡紙、紅麥克筆、藍麥克筆。
///
/// 對比都算過（craft floor 的門檻），而且是用最壞的那個底色算的——紅字會壓在桌面上，
/// 所以紅筆看的是「對桌面」不是「對卡片」：紅筆 4.9:1、次要文字 4.7:1、藍筆 5.6:1，
/// 深色模式也各自過關。顏色會跟著系統外觀自己換，不是兩套手動維護。
enum Marker {

    /// 桌面：貼著卡紙的那張桌子。
    static let paper = Color.dynamic(light: 0xF1EEE6, dark: 0x131416)

    /// 卡紙。
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x1E2023)

    /// 墨黑：印刷的欄位與內文。
    static let ink = Color.dynamic(light: 0x16181A, dark: 0xF2F0EA)

    /// 次要文字。小字也要過 4.5:1，所以不能用淺灰。
    static let faded = Color.dynamic(light: 0x6E6A5F, dark: 0x9A968C)

    /// 紅麥克筆：現在的數字。
    /// 淺色用 0xC42B22 而不是更亮的紅，因為 14pt 的紅字會直接壓在桌面上，
    /// 那個組合要過 4.5:1（4.87:1）。深色沒有這個問題。
    static let red = Color.dynamic(light: 0xC42B22, dark: 0xFF6A5C)

    /// 藍麥克筆：抬頭、註記、外框。
    static let blue = Color.dynamic(light: 0x1F4FD8, dark: 0x7FA6FF)

    /// 細線。
    static let hair = Color.dynamic(light: 0x16181A, dark: 0xF2F0EA).opacity(0.16)

    /// 紅筆上的字。淺色模式用白色（4.7:1）；深色模式的紅被提亮過，
    /// 白字只剩 2.8:1，所以那裡改用近黑（6.7:1）。
    static let onRed = Color.dynamic(light: 0xFFFFFF, dark: 0x1A0A08)

    /// 卡在紙上的影子。深色模式沒有影子可讀，改用一條亮邊。
    static let cardShadow = Color.black.opacity(0.10)
}

extension Color {
    /// 同一個顏色在淺色與深色模式下的值。
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
