import Foundation

/// 一筆加油紀錄的最小形狀：只有使用者真正輸入的四個值。
struct RefuelSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let recordedAt: Date
    let odometerKm: Double
    let amountNTD: Double
    let liters: Double
}

/// 一筆紀錄，加上它自己推導出來、使用者不需要輸入的數字。
struct FuelEntry: Identifiable, Equatable, Sendable {
    let snapshot: RefuelSnapshot

    /// 時間順序上的前一筆里程。第一筆沒有基準，所以是 nil。
    let previousOdometerKm: Double?

    var id: UUID { snapshot.id }

    /// 里程表不會倒退。比上一筆低，就是輸入有問題，不是車子倒著開。
    var odometerWentBackwards: Bool {
        guard let previousOdometerKm else { return false }
        return snapshot.odometerKm < previousOdometerKm
    }

    /// 上次加油到這次之間跑了多少公里。第一筆沒有基準，倒退的那筆不算。
    var distanceKm: Double? {
        guard let previousOdometerKm, !odometerWentBackwards else { return nil }
        let distance = snapshot.odometerKm - previousOdometerKm
        return distance > 0 ? distance : nil
    }

    /// 這次的油錢 ÷ 這次的公升數。使用者沒輸入單價，但簽單上本來就有。
    var unitPriceNTD: Double? {
        snapshot.liters > 0 ? snapshot.amountNTD / snapshot.liters : nil
    }

    /// 這次的公升數，燒的就是上次到這次之間的里程——前提是每次都加滿。
    var fuelEconomyKmPerL: Double? {
        guard let distanceKm, snapshot.liters > 0 else { return nil }
        return distanceKm / snapshot.liters
    }

    /// 這次的油錢，攤在這次跑的每一公里上。
    var costPerKmNTD: Double? {
        guard let distanceKm, distanceKm > 0 else { return nil }
        return snapshot.amountNTD / distanceKm
    }

    /// 算不出里程差的那幾筆（第一筆、里程倒退那筆）不能進平均值，否則平均會被稀釋。
    var countsTowardAverages: Bool { fuelEconomyKmPerL != nil }
}

/// 這份統計現在能不能信。畫面必須誠實說出它處於哪一種。
enum StatsReadiness: Equatable, Sendable {
    /// 一筆紀錄都沒有。
    case noRecords
    /// 只有一筆，還沒有里程差可以算。
    case waitingForSecondRecord
    /// 最新一筆的里程比上一筆低，那一筆不算，平均值可能不是最新狀態。
    case latestOdometerWentBackwards
    /// 中間有里程倒退被排除。平均值還在，但要說出來是哪幾筆，
    /// 而且被排除那筆的下一段是從那個可疑的里程算起的。
    case someRecordsExcluded(count: Int)
    /// 有可以信的數字。
    case ready
}

/// 畫面上那幾個大字背後的完整算法。
struct FuelSummary: Equatable, Sendable {
    /// 總共記了幾筆。
    var recordCount: Int = 0
    /// 其中真的有里程差、能進平均的有幾筆。
    var countedCount: Int = 0
    var readiness: StatsReadiness = .noRecords

    var firstOdometerKm: Double?
    var latestOdometerKm: Double?
    var latestEntry: FuelEntry?

    /// 只採計有里程差的區段：里程、公升、油錢三者的總和。
    var countedDistanceKm: Double = 0
    var countedLiters: Double = 0
    var countedAmountNTD: Double = 0

    /// 全部紀錄的總和，用來顯示「到目前為止總共花了多少」。
    var allLiters: Double = 0
    var allAmountNTD: Double = 0

    /// 累計平均油耗：總里程 ÷ 總公升，不是每一筆平均再平均。
    var averageFuelEconomyKmPerL: Double? {
        countedDistanceKm > 0 && countedLiters > 0 ? countedDistanceKm / countedLiters : nil
    }

    /// 累計每公里成本：總油錢 ÷ 總里程。
    var averageCostPerKmNTD: Double? {
        countedDistanceKm > 0 ? countedAmountNTD / countedDistanceKm : nil
    }
}

/// 統計引擎：只依賴 Foundation，所以可以用命令列單獨驗證。
enum FuelStats {

    /// 依時間排序，替每一筆接上「上一筆里程」，再算出各自的油耗與成本。
    ///
    /// 時間相同時保留傳入順序（呼叫端以 createdAt 排序），這樣同一天補登兩筆也不會亂。
    static func entries(from snapshots: [RefuelSnapshot]) -> [FuelEntry] {
        let ordered = snapshots.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.recordedAt == rhs.element.recordedAt { return lhs.offset < rhs.offset }
                return lhs.element.recordedAt < rhs.element.recordedAt
            }
            .map(\.element)

        var result: [FuelEntry] = []
        result.reserveCapacity(ordered.count)

        for (index, snapshot) in ordered.enumerated() {
            let previous = index > 0 ? ordered[index - 1].odometerKm : nil
            result.append(FuelEntry(snapshot: snapshot, previousOdometerKm: previous))
        }
        return result
    }

    static func summary(from entries: [FuelEntry]) -> FuelSummary {
        var summary = FuelSummary()
        summary.recordCount = entries.count
        summary.firstOdometerKm = entries.first?.snapshot.odometerKm
        summary.latestOdometerKm = entries.last?.snapshot.odometerKm
        summary.latestEntry = entries.last

        for entry in entries {
            summary.allLiters += entry.snapshot.liters
            summary.allAmountNTD += entry.snapshot.amountNTD

            guard entry.countsTowardAverages, let distance = entry.distanceKm else { continue }
            summary.countedCount += 1
            summary.countedDistanceKm += distance
            summary.countedLiters += entry.snapshot.liters
            summary.countedAmountNTD += entry.snapshot.amountNTD
        }

        let excludedCount = excludedCount(in: entries)

        if entries.isEmpty {
            summary.readiness = .noRecords
        } else if summary.countedCount == 0 {
            summary.readiness = (entries.last?.odometerWentBackwards ?? false)
                ? .latestOdometerWentBackwards
                : .waitingForSecondRecord
        } else if entries.last?.odometerWentBackwards == true {
            summary.readiness = .latestOdometerWentBackwards
        } else if excludedCount > 0 {
            // 不是最新那筆倒退，而是中間某幾筆。這種以前會安靜地當成 .ready，
            // 畫面上完全看不出有一筆被丟掉。
            summary.readiness = .someRecordsExcluded(count: excludedCount)
        } else {
            summary.readiness = .ready
        }

        return summary
    }

    /// 被排除在平均之外的筆數（不含第一筆基準——那是規則，不是意外）。
    static func excludedCount(in entries: [FuelEntry]) -> Int {
        entries.filter(\.odometerWentBackwards).count
    }

    static func build(from snapshots: [RefuelSnapshot]) -> (entries: [FuelEntry], summary: FuelSummary) {
        let entries = entries(from: snapshots)
        return (entries, summary(from: entries))
    }

    /// 補登一筆時，要知道「這一筆的上一筆里程」是多少，才能當場告訴使用者油耗。
    ///
    /// 用日期判斷：取時間上不晚於這一筆的最後一筆紀錄。比第一筆還早就是 nil。
    static func previousOdometer(before date: Date, in snapshots: [RefuelSnapshot]) -> Double? {
        snapshots
            .filter { $0.recordedAt <= date }
            .max { $0.recordedAt < $1.recordedAt }?
            .odometerKm
    }
}
