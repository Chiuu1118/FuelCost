import Foundation

/// 畫圖用的種子。
///
/// 不能直接用 `hashValue`：Swift 的 `hashValue` 每個 process 都重新加鹽，
/// 同一個數字每次開啟 app 都會長得不一樣、卡片的歪斜角度也會跳。
/// 這個世界的前提是「同一個數字永遠長得一樣」，所以自己算一個穩定的。
enum Stable {
    /// FNV-1a，64 位。回傳非負整數，可以直接取餘數或相加。
    static func hash(_ text: String) -> Int {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01b3
        }
        // 只留 63 位，保證非負：後面會做 % 與 &+，不需要處理 Int.min。
        return Int(value & 0x7fff_ffff_ffff_ffff)
    }

    /// 數字用它的十進位寫法當輸入，所以 45210 永遠得到同一個種子。
    static func hash(_ number: Double) -> Int {
        hash(String(number))
    }

    static func hash(_ number: Int) -> Int {
        hash(String(number))
    }
}
