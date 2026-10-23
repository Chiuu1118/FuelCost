import Foundation

// 這個檔案不進 app，只是拿來把純邏輯（解析器、統計引擎）在命令列上真的跑一遍。
//   swiftc FuelCost/Models/FuelStats.swift FuelCost/Services/FuelPumpParser.swift Tools/core-check.swift -o /tmp/corecheck && /tmp/corecheck

@main
enum CoreCheck {
    static func main() {
        run()
        print(failures == 0 ? "\n全部通過" : "\n有 \(failures) 項沒過")
        exit(failures == 0 ? 0 : 1)
    }
}

var failures = 0

func check(_ label: String, _ condition: Bool, _ detail: String = "") {
    if condition {
        print("  ok   \(label)")
    } else {
        failures += 1
        print("  FAIL \(label) \(detail)")
    }
}

func near(_ value: Double?, _ expected: Double, _ tolerance: Double = 0.011) -> Bool {
    guard let value else { return false }
    return abs(value - expected) <= tolerance
}

func run() {
    print("FuelPumpParser")

    do {
        let reading = FuelPumpParser.parse("加油機 03\n95無鉛汽油\n單價 31.6\n公升 32.40\n金額 1024")
        check("標籤齊全：金額", near(reading.amountNTD, 1024))
        check("標籤齊全：公升", near(reading.liters, 32.40))
        check("標籤齊全：單價", near(reading.unitPriceNTD, 31.6))
        check("標籤齊全：信心", reading.confidence == .labeled, reading.confidence.rawValue)
        check("標籤齊全：沒有警告", reading.warnings.isEmpty, reading.warnings.joined(separator: " / "))
    }

    do {
        // 加油機 LED 只跳數字，沒有標籤。32.40 × 31.6 = 1023.84 ≈ 1024
        let reading = FuelPumpParser.parse("32.40\n31.6\n1024")
        check("無標籤推論：金額", near(reading.amountNTD, 1024, 1))
        check("無標籤推論：公升", near(reading.liters, 32.40))
        check("無標籤推論：單價", near(reading.unitPriceNTD, 31.6))
        check("無標籤推論：信心是推論", reading.confidence == .inferred, reading.confidence.rawValue)
    }

    do {
        // 只有單價與金額，公升數要用除的；單價不可以被當成公升數。
        let reading = FuelPumpParser.parse("單價 31.6\n金額 1024")
        check("缺公升：沒有把單價誤當公升", near(reading.liters, 32.41, 0.02), "讀到 \(String(describing: reading.liters))")
        check("缺公升：金額保留", near(reading.amountNTD, 1024))
        check("缺公升：信心是推論", reading.confidence == .inferred, reading.confidence.rawValue)
    }

    do {
        let reading = FuelPumpParser.parse("金額　１，０２４ 元\n公升　３２．４０")
        check("全形＋千分位：金額", near(reading.amountNTD, 1024))
        check("全形＋千分位：公升", near(reading.liters, 32.40))
        check("全形＋千分位：單價由除法補上", near(reading.unitPriceNTD, 31.6, 0.02))
    }

    do {
        let reading = FuelPumpParser.parse("統一編號 12345678\n加油機 05\n金額 780\n公升 24.68")
        check("雜訊行：金額不是統編", near(reading.amountNTD, 780), "讀到 \(String(describing: reading.amountNTD))")
        check("雜訊行：公升", near(reading.liters, 24.68))
    }

    do {
        let reading = FuelPumpParser.parse("金額 1O24\n公升 32.4O")
        check("OCR 混淆 O→0：金額", near(reading.amountNTD, 1024), "讀到 \(String(describing: reading.amountNTD))")
        check("OCR 混淆 O→0：公升", near(reading.liters, 32.40), "讀到 \(String(describing: reading.liters))")
    }

    do {
        let reading = FuelPumpParser.parse("總計 1,024\n加油量 32.4 L")
        check("英文單位 L：金額", near(reading.amountNTD, 1024))
        check("英文單位 L：公升", near(reading.liters, 32.4))
    }

    do {
        let reading = FuelPumpParser.parse("公升 32.40")
        check("只讀到公升：公升值正確", near(reading.liters, 32.40))
        check("只讀到公升：金額留白", reading.amountNTD == nil)
        check("只讀到公升：沒有單價", reading.unitPriceNTD == nil)
        check("只讀到公升：不算完全辨識", reading.confidence == .labeled)
    }

    do {
        let reading = FuelPumpParser.parse("歡迎光臨 中油 大直站")
        check("沒有數字：什麼都不填", reading.isEmpty)
        check("沒有數字：信心 none", reading.confidence == .none)
    }

    do {
        // 金額與公升數對不上合理的單價時要出聲，而不是安靜地算。
        let reading = FuelPumpParser.parse("單價 31.6\n金額 2,400\n公升 32.40")
        check("對不上時出警告", !reading.warnings.isEmpty, "沒有警告")
    }

    do {
        // 回歸：台灣最常見的簽單排版，「單價 31.6 元/公升」也含「公升」兩個字。
        // 曾經因此把單價當成公升數、單價欄再去撿下一行的真容積——兩欄對調而且零警告。
        let reading = FuelPumpParser.parse(
            "95無鉛汽油\n單價 31.6 元/公升\n數量 32.40公升\n金額 1,024元")
        check("元/公升：公升數不會被填成單價", near(reading.liters, 32.40), "讀到 \(reading.liters ?? -1)")
        check("元/公升：單價正確", near(reading.unitPriceNTD, 31.6), "讀到 \(reading.unitPriceNTD ?? -1)")
        check("元/公升：金額正確", near(reading.amountNTD, 1024))
    }

    do {
        // 同一件事的純 ASCII 版本。
        let reading = FuelPumpParser.parse("單價31.6元/公升\n公升32.40\n金額1024")
        check("ASCII 元/公升：公升數正確", near(reading.liters, 32.40), "讀到 \(reading.liters ?? -1)")
        check("ASCII 元/公升：單價正確", near(reading.unitPriceNTD, 31.6), "讀到 \(reading.unitPriceNTD ?? -1)")
    }

    do {
        // 回歸：OCR 很常把「公升」和它的數字拆成上下兩行。
        // 要求相鄰的時候如果就這樣放棄，這裡會退化成用金額÷單價推出來的值，
        // 而且信心從 labeled 掉成 inferred。
        let reading = FuelPumpParser.parse("單價\n31.6\n公升\n32.40\n金額\n1,024")
        check("數字在下一行：公升數要讀到", near(reading.liters, 32.40), "讀到 \(reading.liters ?? -1)")
        check("數字在下一行：還算標籤確認", reading.confidence == .labeled, "\(reading.confidence)")
        check("數字在下一行：單價正確", near(reading.unitPriceNTD, 31.6), "讀到 \(reading.unitPriceNTD ?? -1)")
    }

    do {
        // 辛烷值（92／95／98）不是容積。收窄容積範圍就是為了擋這個。
        let reading = FuelPumpParser.parse("92無鉛 每公升 30.1 元\n加油量 32.40 公升\n金額 1024 元")
        check("辛烷值不會被當成公升數", near(reading.liters, 32.40), "讀到 \(reading.liters ?? -1)")
        check("辛烷值：單價正確", near(reading.unitPriceNTD, 30.1), "讀到 \(reading.unitPriceNTD ?? -1)")
    }

    print("FuelStats")

    do {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func snapshot(_ dayOffset: Double, _ odometer: Double, _ amount: Double, _ liters: Double) -> RefuelSnapshot {
            RefuelSnapshot(
                id: UUID(),
                recordedAt: base.addingTimeInterval(dayOffset * 86_400),
                odometerKm: odometer,
                amountNTD: amount,
                liters: liters
            )
        }

        // 第一筆沒有里程差；第二、三筆有。第四筆里程倒退，不算。
        let snapshots = [
            snapshot(0, 44_310, 1_070, 33.85),
            snapshot(17, 44_762, 982, 31.10),
            snapshot(34, 45_210, 1_024, 32.40),
            snapshot(51, 44_900, 900, 28.00),
        ]

        let built = FuelStats.build(from: snapshots)
        check("四筆都留著", built.entries.count == 4)
        check("第一筆沒有里程差", built.entries[0].distanceKm == nil)
        check("第二筆里程差", near(built.entries[1].distanceKm, 452))
        check("第二筆油耗", near(built.entries[1].fuelEconomyKmPerL, 452 / 31.10, 0.001))
        check("倒退那筆被標記", built.entries[3].odometerWentBackwards)
        check("倒退那筆不進平均", !built.entries[3].countsTowardAverages)

        let summary = built.summary
        check("只採計兩筆", summary.countedCount == 2, "\(summary.countedCount)")
        check("累計里程 448 + 452", near(summary.countedDistanceKm, 900))
        check("累計公升只算採計的", near(summary.countedLiters, 31.10 + 32.40))
        check("累計平均油耗", near(summary.averageFuelEconomyKmPerL, 900 / 63.50, 0.001))
        check("每公里成本", near(summary.averageCostPerKmNTD, (982 + 1_024) / 900, 0.001))
        check("全部紀錄的總花費", near(summary.allAmountNTD, 1_070 + 982 + 1_024 + 900))
        check("狀態是里程倒退", summary.readiness == .latestOdometerWentBackwards, "\(summary.readiness)")
    }

    do {
        // 回歸：倒退的不是最後一筆，而是中間那一筆。
        // 以前這種情況會安靜地當成 .ready，畫面上完全看不出有一筆被丟掉。
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func snapshot(_ dayOffset: Double, _ odometer: Double) -> RefuelSnapshot {
            RefuelSnapshot(
                id: UUID(),
                recordedAt: base.addingTimeInterval(dayOffset * 86_400),
                odometerKm: odometer,
                amountNTD: 1_200,
                liters: 40
            )
        }
        // 第 3 筆（1800）比第 2 筆（1900）低：倒退的是中間那筆，不是最後一筆。
        let built = FuelStats.build(from: [
            snapshot(0, 1_000),
            snapshot(10, 1_900),
            snapshot(20, 1_800),
            snapshot(30, 2_100),
        ])
        let summary = built.summary
        check("中間倒退：被標記", built.entries[2].odometerWentBackwards)
        check("中間倒退：不進平均", !built.entries[2].countsTowardAverages)
        check("中間倒退：狀態要說出來",
              summary.readiness == .someRecordsExcluded(count: 1),
              "\(summary.readiness)")
        check("中間倒退：排除筆數", FuelStats.excludedCount(in: built.entries) == 1)
    }

    do {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let one = RefuelSnapshot(id: UUID(), recordedAt: base, odometerKm: 44_310, amountNTD: 1_070, liters: 33.85)
        let summary = FuelStats.summary(from: FuelStats.entries(from: [one]))
        check("只有一筆：狀態是等第二筆", summary.readiness == .waitingForSecondRecord, "\(summary.readiness)")
        check("只有一筆：平均油耗留白", summary.averageFuelEconomyKmPerL == nil)
        check("只有一筆：每公里成本留白", summary.averageCostPerKmNTD == nil)

        let empty = FuelStats.summary(from: [])
        check("沒有紀錄：狀態是空的", empty.readiness == .noRecords)
    }
}
