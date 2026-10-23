#if DEBUG
import Foundation
import SwiftData
import SwiftUI

/// 開發用的後門：帶 `-seedSampleData` 啟動時，清空資料庫並帶入示範資料，
/// 順便把算出來的平均值印到主控台。
///
/// 存在的理由很實際：截圖驗證時總得有個畫面有資料的樣子，而模擬器沒辦法幫我點按鈕。
/// Release 版本整段都編不進去。
enum DevelopmentSupport {

    static let seedArgument = "-seedSampleData"

    /// 開發用的啟動參數，讓模擬器不必點按鈕就能走到某一頁：
    ///
    ///   -startTab dashboard|history|trends
    ///   -openEntry            直接開「記一筆」
    ///   -openEntryScanned     開「記一筆」並當場跑一次示範照片的辨識
    @MainActor
    static func applyLaunchArguments(appState: AppState) {
        let arguments = ProcessInfo.processInfo.arguments

        if let index = arguments.firstIndex(of: "-startTab"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "history": appState.selectedTab = .history
            case "trends": appState.selectedTab = .trends
            default: appState.selectedTab = .dashboard
            }
        }

        if arguments.contains("-openEntry") || arguments.contains("-openEntryScanned") {
            appState.entryRoute = .new
            appState.demoScanOnOpen = arguments.contains("-openEntryScanned")
        }
    }

    /// 當場畫一張假的油機顯示當作示範照片。
    ///
    /// 不用真的打包一張測試圖進 app：Release 版本不該帶著測試素材，
    /// 而辨識流程走的是同一條真的路徑。
    static func demoPumpImage() -> UIImage {
        let size = CGSize(width: 900, height: 700)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor(white: 0.11, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let labelFont = UIFont.systemFont(ofSize: 54, weight: .semibold)
            let valueFont = UIFont.monospacedDigitSystemFont(ofSize: 96, weight: .medium)
            let labelColor = UIColor(white: 0.52, alpha: 1)
            let valueColor = UIColor(white: 0.86, alpha: 1)

            let rows: [(label: String, value: String)] = [
                ("單價", "31.6"),
                ("公升", "32.40"),
                ("金額", "1,024"),
            ]

            for (index, row) in rows.enumerated() {
                let y = CGFloat(90 + index * 180)
                (row.label as NSString).draw(
                    at: CGPoint(x: 80, y: y),
                    withAttributes: [.font: labelFont, .foregroundColor: labelColor]
                )
                let valueSize = (row.value as NSString).size(withAttributes: [.font: valueFont])
                (row.value as NSString).draw(
                    at: CGPoint(x: size.width - 80 - valueSize.width, y: y - 24),
                    withAttributes: [.font: valueFont, .foregroundColor: valueColor]
                )
            }
        }
    }

    @MainActor
    static func handleLaunchArguments(context: ModelContext, existing: [RefuelRecord]) {
        guard ProcessInfo.processInfo.arguments.contains(seedArgument) else { return }

        for record in existing {
            if let photo = record.photoFileName { PhotoStore.delete(photo) }
            context.delete(record)
        }
        SampleData.seed(into: context)

        do {
            try context.save()
            report(context: context)
        } catch {
            print("[示範資料] 存不進去：\(error)")
        }
    }

    @MainActor
    static func report(context: ModelContext) {
        let descriptor = FetchDescriptor<RefuelRecord>(sortBy: [SortDescriptor(\.createdAt)])
        guard let records = try? context.fetch(descriptor) else { return }

        let summary = FuelStats.summary(from: FuelStats.entries(from: records.map(\.snapshot)))
        print("[示範資料] 總共 \(summary.recordCount) 筆，採計 \(summary.countedCount) 筆")

        if let distance = summary.countedDistanceKm as Double?,
           let liters = summary.countedLiters as Double?,
           let amount = summary.countedAmountNTD as Double? {
            print(String(format: "[示範資料] 採計里程 %.0f km／公升 %.2f L／油錢 %.0f 元", distance, liters, amount))
        }
        if let economy = summary.averageFuelEconomyKmPerL {
            print(String(format: "[示範資料] 平均油耗 %.2f km/L", economy))
        }
        if let cost = summary.averageCostPerKmNTD {
            print(String(format: "[示範資料] 每公里成本 NT$%.2f", cost))
        }
        if let latest = summary.latestEntry {
            print(String(format: "[示範資料] 最新里程 %.0f km，這一筆 %@", latest.snapshot.odometerKm,
                         latest.fuelEconomyKmPerL.map { String(format: "%.2f km/L", $0) } ?? "無法計算"))
        }
    }
}
#endif
