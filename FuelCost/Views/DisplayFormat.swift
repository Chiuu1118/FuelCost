import Foundation

/// 畫面上數字的寫法。全部集中在這裡，免得同一個數字在三個地方長得三種樣子。
enum DisplayFormat {

    private static let tw = Locale(identifier: "zh_TW")

    /// 45,210
    static func km(_ value: Double) -> String {
        integer(value)
    }

    /// 1,024
    static func money(_ value: Double) -> String {
        integer(value)
    }

    /// 13.55
    static func economy(_ value: Double) -> String {
        decimals(value, 2)
    }

    /// 2.34
    static func cost(_ value: Double) -> String {
        decimals(value, 2)
    }

    /// 31.60
    static func unitPrice(_ value: Double) -> String {
        decimals(value, 2)
    }

    /// 32.40
    static func liters(_ value: Double) -> String {
        decimals(value, 2)
    }

    static func integer(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = tw
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSNumber) ?? String(format: "%.0f", value)
    }

    static func decimals(_ value: Double, _ places: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = tw
        formatter.minimumFractionDigits = places
        formatter.maximumFractionDigits = places
        return formatter.string(from: value as NSNumber) ?? String(format: "%.\(places)f", value)
    }

    /// 輸入框裡的字：不要顯示 1024.0 這種東西。
    static func decimalString(_ value: Double, places: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = places
        return formatter.string(from: value as NSNumber) ?? String(format: "%.\(places)f", value)
    }

    /// 2026/10/16
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = tw
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }

    /// 10 月 16 日
    static func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = tw
        formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: date)
    }

    /// 2026 年 10 月
    static func month(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = tw
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: date)
    }

    /// 星期幾，用在日期挑選器旁邊。
    static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = tw
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
