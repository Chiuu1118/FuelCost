#if DEBUG
import Foundation
import SwiftData

/// 示範資料。只有開發版編得進來，而且畫面上會標成「示範資料」。
///
/// 這些數字彼此自洽：每一筆的公升數就是該段行駛里程 ÷ 該段油耗，
/// 金額就是公升數 × 當時油價（四捨五入到元）。所以平均值算出來是真的。
enum SampleData {

    /// (日期, 里程 km, 油錢 NT$, 公升)
    static let rows: [(day: String, odometer: Double, amount: Double, liters: Double)] = [
        ("2026-03-27", 39672, 1089, 35.60),
        ("2026-04-10", 40086, 966, 31.36),
        ("2026-04-25", 40501, 994, 32.17),
        ("2026-05-09", 40917, 920, 29.50),
        ("2026-05-24", 41313, 921, 29.33),
        ("2026-06-07", 41731, 1016, 32.15),
        ("2026-06-22", 42108, 863, 27.32),
        ("2026-07-06", 42486, 891, 28.21),
        ("2026-07-21", 42907, 933, 29.24),
        ("2026-08-04", 43302, 962, 30.15),
        ("2026-08-19", 43677, 885, 27.57),
        ("2026-09-02", 44072, 914, 28.21),
        ("2026-09-17", 44442, 901, 27.82),
        ("2026-10-01", 44815, 888, 27.23),
        ("2026-10-16", 45210, 904, 28.42),
    ]

    static func snapshots() -> [RefuelSnapshot] {
        rows.compactMap { row -> RefuelSnapshot? in
            guard let day = date(from: row.day) else { return nil }
            return RefuelSnapshot(
                id: UUID(),
                recordedAt: day,
                odometerKm: row.odometer,
                amountNTD: row.amount,
                liters: row.liters
            )
        }
    }

    static func seed(into context: ModelContext) {
        for (index, row) in rows.enumerated() {
            guard let date = date(from: row.day) else { continue }
            let record = RefuelRecord(
                recordedAt: date,
                odometerKm: row.odometer,
                amountNTD: row.amount,
                liters: row.liters,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
            )
            context.insert(record)
        }
    }

    /// 給 SwiftUI preview 用：記憶體裡的容器，已經帶好示範資料。
    ///
    /// 這裡的 try! 是刻意的：preview 建不起來就代表模型定義有問題，
    /// 這種錯誤要當場炸掉，不要安靜地給一張空畫面。
    @MainActor
    static func previewContainer() -> ModelContainer {
        let container = try! ModelContainer(
            for: RefuelRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        seed(into: container.mainContext)
        return container
    }

    private static func date(from day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 8
        components.minute = 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei") ?? .current
        return calendar.date(from: components)
    }
}
#endif
