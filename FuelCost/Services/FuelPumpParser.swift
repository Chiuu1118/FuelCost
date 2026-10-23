import Foundation

/// 從加油機或簽單上讀到的三個數字。
///
/// 每一個都可能是 nil。這裡的規則是：讀不出來就留白，讓使用者自己打，
/// 不要為了畫面好看猜一個數字填上去。
struct FuelPumpReading: Equatable, Sendable {
    enum Confidence: String, Equatable, Sendable {
        /// 每個讀到的值都有標籤直接指認。
        case labeled
        /// 至少一個值是靠關係推出來的（單價 × 公升 = 金額）。
        case inferred
        /// 什麼都沒讀出來。
        case none
    }

    var amountNTD: Double?
    var liters: Double?
    var unitPriceNTD: Double?
    var confidence: Confidence = .none
    /// 哪幾行文字被採用，讓使用者可以自己核對。
    var evidence: [String] = []
    /// 讀到了、但看起來不太對的地方。
    var warnings: [String] = []

    var isEmpty: Bool { amountNTD == nil && liters == nil }

    /// 兩個關鍵數字都有了，這一筆可以直接用。
    var isComplete: Bool { amountNTD != nil && liters != nil }

    /// 金額 ÷ 公升 得到的單價，用來檢查這組數字合不合理。
    var impliedUnitPrice: Double? {
        guard let amountNTD, let liters, liters > 0 else { return nil }
        return amountNTD / liters
    }

    /// 台灣 95 無鉛的合理區間；超出這個範圍就是讀錯了。
    static let plausibleUnitPriceRange: ClosedRange<Double> = 15...60
}

/// 加油機數字解析。純 Foundation，可以被命令列直接跑起來驗證。
enum FuelPumpParser {

    // MARK: - 入口

    static func parse(_ text: String) -> FuelPumpReading {
        let lines = normalize(text)
        guard !lines.isEmpty else { return FuelPumpReading() }

        // 已經被某一欄認領的數字，不能被下一欄再用一次。
        // 注意：這一步只擋得住「同一行重複取用」，擋不住兩欄互相對調——
        // 所以公升數那一欄另外要求「數字必須緊貼容積字」，見 rejectsPriceLines／adjacentValue。
        var claimed: Set<Double> = []

        let liters = extract(
            lines,
            unitWords: ["公升", "升", "ℓ", "L", "liter", "litre"],
            labelWords: ["公升", "加油量", "數量", "容積", "liter", "litre"],
            // 油箱不可能只加 4 公升，也不可能一次 130 公升；收窄範圍讓辛烷值（92、95、98）
            // 沒有機會被當成容積。
            range: 5...120,
            claimed: &claimed,
            // 「單價 31.6 元/公升」也含「公升」兩個字。不擋掉這種價格行，
            // 公升數就會被填成單價，而單價那一欄再去撿下一行的真容積——兩欄對調。
            rejectsPriceLines: true,
            adjacentValue: /(?:公升|加油量|數量|容積|liter|litre)\s*[:：]?\s*(\d+(?:\.\d+)?)/
        )
        let unit = extract(
            lines,
            unitWords: [],
            labelWords: ["單價", "每公升", "油價", "price"],
            range: FuelPumpReading.plausibleUnitPriceRange,
            claimed: &claimed
        )
        let amount = extract(
            lines,
            unitWords: ["元", "NT$", "NTD"],
            labelWords: ["金額", "應付", "合計", "總計", "小計", "total", "amount"],
            range: 50...100_000,
            claimed: &claimed,
            rejectsEightDigitIntegers: true
        )

        var reading = FuelPumpReading()
        reading.liters = liters.value
        reading.unitPriceNTD = unit.value
        reading.amountNTD = amount.value
        reading.evidence = [liters.evidence, unit.evidence, amount.evidence].compactMap { $0 }

        var inferred = [liters, unit, amount].contains { $0.value != nil && !$0.isLabeled }

        // 三個數字互相對帳：單價 × 公升 應該等於金額。
        if let price = reading.unitPriceNTD, price > 0 {
            switch (reading.amountNTD, reading.liters) {
            case (let amountValue?, let litersValue?) where litersValue > 0:
                let expected = litersValue * price
                let tolerance = max(1.0, expected * 0.02)
                if abs(amountValue - expected) > tolerance {
                    if !amount.isLabeled {
                        reading.amountNTD = round2(expected)
                        reading.evidence.append("金額與單價對不上，改用 \(format(price)) × \(format(litersValue))")
                        inferred = true
                    } else if !liters.isLabeled {
                        reading.liters = round2(amountValue / price)
                        reading.evidence.append("公升數與單價對不上，改用 \(format(amountValue)) ÷ \(format(price))")
                        inferred = true
                    } else {
                        reading.warnings.append(
                            "金額 \(format(amountValue)) 元與 \(format(litersValue)) 公升 ≈ \(format(price)) 元/公升對不上，請自己再看一眼。"
                        )
                    }
                }
            case (let amountValue?, nil):
                reading.liters = round2(amountValue / price)
                reading.evidence.append("用 \(format(amountValue)) 元 ÷ \(format(price)) 元/公升補出公升數")
                inferred = true
            case (nil, let litersValue?):
                reading.amountNTD = round2(litersValue * price)
                reading.evidence.append("用 \(format(price)) 元/公升 × \(format(litersValue)) 公升補出金額")
                inferred = true
            default:
                break
            }
        }

        // 沒有單價可以對帳，而兩個關鍵數字都還沒著落時，才動用純數值推論。
        if reading.amountNTD == nil && reading.liters == nil {
            if let guess = inferFromNumbers(lines) {
                reading.amountNTD = guess.amount
                reading.liters = guess.liters
                reading.unitPriceNTD = guess.unitPrice
                reading.evidence.append(guess.evidence)
                inferred = true
            }
        }

        // 有金額與公升數卻沒有單價時，單價是除出來的，不是讀出來的。
        if reading.unitPriceNTD == nil,
           let amountValue = reading.amountNTD,
           let litersValue = reading.liters,
           litersValue > 0 {
            reading.unitPriceNTD = amountValue / litersValue
            reading.evidence.append("單價由金額 ÷ 公升算出")
        }

        if reading.isEmpty {
            reading.confidence = .none
        } else {
            reading.confidence = inferred ? .inferred : .labeled
        }

        reading.warnings.append(contentsOf: warnings(for: reading))
        return reading
    }

    // MARK: - 單一欄位

    private struct Field {
        var value: Double?
        var evidence: String?
        var isLabeled = false

        static let empty = Field()
    }

    /// 抽一個欄位。兩條路，先強後弱：
    ///
    /// 1. **黏著單位**：`32.40公升`、`1,024元`。數字與單位在同一行，最可信。
    /// 2. **標籤指路**：`單價`／`金額`／`公升` 這種字。數字可能在同行，
    ///    也可能被 OCR 丟到下一行——簽單的兩欄排版常常被拆成兩行。
    private static func extract(
        _ lines: [String],
        unitWords: [String],
        labelWords: [String],
        range: ClosedRange<Double>,
        claimed: inout Set<Double>,
        rejectsEightDigitIntegers: Bool = false,
        rejectsPriceLines: Bool = false,
        adjacentValue: Regex<(Substring, Substring)>? = nil
    ) -> Field {
        var labeledFallback: Field?

        for (index, line) in lines.enumerated() where !isNoise(line) {
            // 價格行（元/公升、每公升）講的是單價，不是容積，整行跳過。
            if rejectsPriceLines,
               line.contains(/每\s*公升/) || line.contains(/(?:元|NT\$|\$)\s*\/\s*公升/) {
                continue
            }

            let cleaned = repairDigitConfusions(line)

            // 1. 數字黏著單位
            if !unitWords.isEmpty {
                for match in cleaned.matches(of: /(\d+(?:\.\d+)?)\s*([^\d\s]{1,4}|[A-Za-z$]{1,3})/) {
                    let unit = String(match.2)
                    guard unitWords.contains(where: { $0.caseInsensitiveCompare(unit) == .orderedSame }),
                          let value = Double(String(match.1)),
                          range.contains(value),
                          !claimed.contains(value) else { continue }
                    claimed.insert(value)
                    return Field(value: value, evidence: "\(unitWords[0])：\(line)", isLabeled: true)
                }
            }

            // 2. 標籤指路
            guard labelWords.contains(where: { line.localizedCaseInsensitiveContains($0) }) else { continue }

            // 有些欄位（公升數）要求數字緊貼著自己的單位或標籤。同一行裡東一個西一個的
            // 數字不算數——那個數字通常是別欄的。
            if let adjacentValue {
                if let match = cleaned.firstMatch(of: adjacentValue),
                   let value = Double(String(match.1)),
                   range.contains(value),
                   !claimed.contains(value) {
                    claimed.insert(value)
                    return Field(value: value, evidence: "標籤：\(line)", isLabeled: true)
                }
                // 同行沒有緊貼的數字時，不能就這樣放棄：OCR 很常把「公升」和它的數字
                // 拆成上下兩行，下面那段「看下一行」就是為此存在的。
            } else if let value = firstNumber(in: cleaned, range: range, claimed: claimed, rejectsEightDigitIntegers: rejectsEightDigitIntegers) {
                claimed.insert(value)
                return Field(value: value, evidence: "標籤：\(line)", isLabeled: true)
            }

            // 同行沒有數字時，看下一行（OCR 常把兩欄排版拆開）。
            if labeledFallback == nil, index + 1 < lines.count, !isNoise(lines[index + 1]) {
                let next = repairDigitConfusions(lines[index + 1])
                if let value = firstNumber(in: next, range: range, claimed: claimed, rejectsEightDigitIntegers: rejectsEightDigitIntegers) {
                    claimed.insert(value)
                    labeledFallback = Field(value: value, evidence: "標籤：\(line) → \(lines[index + 1])", isLabeled: true)
                }
            }
        }

        return labeledFallback ?? .empty
    }

    private static func firstNumber(
        in line: String,
        range: ClosedRange<Double>,
        claimed: Set<Double>,
        rejectsEightDigitIntegers: Bool
    ) -> Double? {
        for match in line.matches(of: /(\d+(?:\.\d+)?)/) {
            let raw = String(match.1)
            guard let value = Double(raw), range.contains(value), !claimed.contains(value) else { continue }
            if rejectsEightDigitIntegers, !raw.contains("."), raw.count == 8 { continue }
            return value
        }
        return nil
    }

    // MARK: - 純數值推論

    private struct Guess {
        var amount: Double
        var liters: Double
        var unitPrice: Double
        var evidence: String
    }

    /// 加油機的 LED 常常只有一排數字、沒有標籤。
    /// 這時候用「單價 × 公升 ≈ 金額」去湊出唯一合理的組合。
    private static func inferFromNumbers(_ lines: [String]) -> Guess? {
        let all = extractedNumbers(in: lines).map(\.value).filter { $0 > 0 }
        guard all.count >= 2 else { return nil }

        let literCandidates = all.filter { (3...150).contains($0) }
        let unitCandidates = all.filter { FuelPumpReading.plausibleUnitPriceRange.contains($0) }
        let amountCandidates = all.filter { (50...20_000).contains($0) }

        var best: (guess: Guess, score: Double)?

        for liters in literCandidates {
            for unit in unitCandidates where unit != liters {
                let expected = liters * unit
                guard let amount = amountCandidates.min(by: { abs($0 - expected) < abs($1 - expected) }) else { continue }
                let tolerance = max(1.0, expected * 0.01)
                let error = abs(amount - expected)
                guard error <= tolerance else { continue }

                // 誤差越小越好；公升有小數點、金額是整數再各加一點分。
                var score = error / tolerance
                if liters != liters.rounded() { score -= 0.1 }
                if amount == amount.rounded() { score -= 0.05 }

                if best == nil || score < best!.score {
                    best = (
                        Guess(
                            amount: amount,
                            liters: liters,
                            unitPrice: unit,
                            evidence: "沒有標籤，用 \(format(unit)) × \(format(liters)) ≈ \(format(amount)) 推出來"
                        ),
                        score
                    )
                }
            }
        }
        return best?.guess
    }

    // MARK: - 數字抽取

    private struct ExtractedNumber {
        var value: Double
        var decimals: Int
        var line: String
    }

    private static func extractedNumbers(in lines: [String]) -> [ExtractedNumber] {
        var found: [ExtractedNumber] = []
        for line in lines where !isNoise(line) {
            let cleaned = repairDigitConfusions(line)
            for match in cleaned.matches(of: /(\d+(?:\.\d+)?)/) {
                let raw = String(match.1)
                guard let value = Double(raw) else { continue }
                let decimals = raw.contains(".") ? (raw.split(separator: ".").last?.count ?? 0) : 0
                found.append(ExtractedNumber(value: value, decimals: decimals, line: line))
            }
        }
        return found
    }

    // MARK: - 清理

    /// 全形轉半形、去掉千分位、統一標點，再切成一行一行。
    static func normalize(_ text: String) -> [String] {
        var s = text
        let fullWidthDigits = "０１２３４５６７８９"
        for (offset, character) in fullWidthDigits.enumerated() {
            s = s.replacingOccurrences(of: String(character), with: String(offset))
        }
        s = s.replacingOccurrences(of: "．", with: ".")
        s = s.replacingOccurrences(of: "。", with: ".")
        s = s.replacingOccurrences(of: "，", with: ",")
        s = s.replacingOccurrences(of: "：", with: ":")
        s = s.replacingOccurrences(of: "\u{3000}", with: " ")
        s = s.replacingOccurrences(of: "Ｌ", with: "L")
        s = s.replacingOccurrences(of: "ｌ", with: "l")
        s = removingThousandsSeparators(s)

        return s
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 1,024 → 1024。只刪掉夾在兩個數字中間的逗號。
    private static func removingThousandsSeparators(_ text: String) -> String {
        let characters = Array(text)
        var result: [Character] = []
        result.reserveCapacity(characters.count)

        for (index, character) in characters.enumerated() {
            if character == ",",
               index > 0, index + 1 < characters.count,
               characters[index - 1].isNumber, characters[index + 1].isNumber {
                continue
            }
            result.append(character)
        }
        return String(result)
    }

    /// OCR 在 LED 數字上最常犯的錯：0 讀成 O、1 讀成 l 或 I。
    /// 只在整串字元都可能是數字、而且長度很短時才修，避免動到真正的英文字。
    private static func repairDigitConfusions(_ line: String) -> String {
        line.split(separator: " ").map { token -> String in
            let characters = Array(token)
            guard (2...8).contains(characters.count) else { return String(token) }
            let hasDigit = characters.contains { $0.isNumber }
            let onlyDigitish = characters.allSatisfy { $0.isNumber || "OoIl.,".contains($0) }
            guard hasDigit, onlyDigitish else { return String(token) }

            return String(characters.map { character -> Character in
                switch character {
                case "O", "o": return "0"
                case "I", "l": return "1"
                default: return character
                }
            })
        }
        .joined(separator: " ")
    }

    /// 這些行裡的數字跟油耗無關，先排除，免得抓到統編或機台號。
    private static func isNoise(_ line: String) -> Bool {
        let noiseKeywords = [
            "統編", "統一編號", "發票", "載具", "機台", "加油機", "日期", "時間",
            "卡號", "信用卡", "交易", "點數", "折抵", "折扣", "車牌", "里程", "表數",
            "營業人", "簽單", "序號", "授權", "電話", "地址",
        ]
        return noiseKeywords.contains { line.contains($0) }
    }

    private static func warnings(for reading: FuelPumpReading) -> [String] {
        var result: [String] = []
        if let implied = reading.impliedUnitPrice,
           !FuelPumpReading.plausibleUnitPriceRange.contains(implied) {
            result.append("金額 ÷ 公升 = \(format(implied)) 元/公升，不像台灣的油價，數字可能讀錯了。")
        }
        if let liters = reading.liters, liters <= 0 { result.append("公升數是 0，請自己填一次。") }
        if let amount = reading.amountNTD, amount <= 0 { result.append("金額是 0，請自己填一次。") }
        return result
    }

    // MARK: - 格式化

    private static func round2(_ value: Double) -> Double { (value * 100).rounded() / 100 }

    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: value as NSNumber) ?? String(value)
    }
}
