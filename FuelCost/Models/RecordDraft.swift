import Foundation

/// 使用者在「記一筆」裡打的三個數字。
///
/// 這裡刻意保留使用者打進去的原始字串：只有這樣才能在欄位旁邊誠實地說
/// 「這裡不是數字」或「里程比上次低」，而不是安靜地當成 0。
struct RecordDraft {
    var odometerText = ""
    var amountText = ""
    var litersText = ""
    var recordedAt = Date()

    /// 這次辨識用的照片檔名（如果有的話）。
    var photoFileName: String?

    /// 辨識來源的一行說明，例如「單價：公升 32.40」。
    var scanNotes: [String] = []

    /// 讀到了、但看起來不對的地方。
    var scanWarnings: [String] = []

    var odometerKm: Double? { Self.number(odometerText) }
    var amountNTD: Double? { Self.number(amountText) }
    var liters: Double? { Self.number(litersText) }

    /// 三個欄位都填了合法的數字才能存。
    var canSave: Bool { odometerKm != nil && amountNTD != nil && liters != nil }

    // MARK: - 驗證

    /// 里程必須比上一筆高。里程表不會倒退，倒退的紀錄會讓油耗變成負的。
    func odometerProblem(previousOdometerKm: Double?) -> String? {
        guard let previousOdometerKm else { return nil }
        if let current = odometerKm, current < previousOdometerKm {
            return "比上一筆的 \(Self.format(previousOdometerKm)) km 還低。里程表不會倒退，這裡可能打錯了。"
        }
        if let current = odometerKm, current == previousOdometerKm {
            return "跟上一筆一樣是 \(Self.format(previousOdometerKm)) km，這樣算不出這次跑了多少。"
        }
        return nil
    }

    /// 只有填了、但填錯的欄位才會出現在這裡。
    func fieldProblems() -> [String] {
        var problems: [String] = []
        if !odometerText.trimmingCharacters(in: .whitespaces).isEmpty, odometerKm == nil {
            problems.append("里程不是數字。")
        }
        if !amountText.trimmingCharacters(in: .whitespaces).isEmpty, amountNTD == nil {
            problems.append("油錢不是數字。")
        }
        if !litersText.trimmingCharacters(in: .whitespaces).isEmpty, liters == nil {
            problems.append("公升數不是數字。")
        }
        if let liters = liters, liters <= 0 { problems.append("公升數要是正的。") }
        if let amount = amountNTD, amount <= 0 { problems.append("油錢要是正的。") }
        if let odometer = odometerKm, odometer < 0 { problems.append("里程不可能是負的。") }
        return problems
    }

    // MARK: - 帶入辨識結果

    /// 把辨識到的數字填進還沒被使用者改過的欄位。
    ///
    /// 只在欄位是空的時候填：使用者已經打好的字不該被辨識結果蓋掉。
    mutating func apply(_ reading: FuelPumpReading, overwriteExisting: Bool = false) {
        if let liters = reading.liters, overwriteExisting || litersText.isEmpty {
            litersText = Self.editable(liters, decimals: 2)
        }
        if let amount = reading.amountNTD, overwriteExisting || amountText.isEmpty {
            amountText = Self.editable(amount, decimals: 0)
        }
        scanNotes = reading.evidence
        scanWarnings = reading.warnings
    }

    // MARK: - 顯示

    /// 這一筆算出來的油耗與每公里成本，讓使用者在存檔前就看到。
    /// 使用者還沒填里程時就是 nil，畫面就留白。
    func preview(previousOdometerKm: Double?) -> (distanceKm: Double, fuelEconomy: Double, costPerKm: Double)? {
        guard let odometer = odometerKm,
              let previousOdometerKm,
              let liters = liters, liters > 0,
              let amount = amountNTD else { return nil }
        let distance = odometer - previousOdometerKm
        guard distance > 0 else { return nil }
        return (distance, distance / liters, amount / distance)
    }

    // MARK: - 數字解析

    /// 接受「45,210」「４５２１０」「１，０２４」這種使用者真的會打進來的樣子。
    static func number(_ text: String) -> Double? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullWidth = "０１２３４５６７８９"
        for (offset, character) in fullWidth.enumerated() {
            cleaned = cleaned.replacingOccurrences(of: String(character), with: String(offset))
        }
        cleaned = cleaned.replacingOccurrences(of: "．", with: ".")
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// 輸入框裡的字：公升數兩位、油錢整數，不要顯示 1024.0 這種東西。
    private static func editable(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: value as NSNumber) ?? String(value)
    }

    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSNumber) ?? String(value)
    }

    static func format(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: value as NSNumber) ?? String(value)
    }
}
