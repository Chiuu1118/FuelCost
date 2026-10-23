import SwiftUI

/// 跨畫面的一點點狀態：現在在哪個分頁、有沒有開著「記一筆」。
///
/// 刻意保持這麼小。真正的資料在 SwiftData，畫面自己用 @Query 拿。
@MainActor
@Observable
final class AppState {

    enum Tab: Hashable {
        case dashboard
        case history
        case trends
    }

    enum EntryRoute: Identifiable {
        case new
        case edit(RefuelRecord)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let record): return record.uuid.uuidString
            }
        }
    }

    var selectedTab: Tab = .dashboard
    var entryRoute: EntryRoute?

    /// 剛存好一筆時加一。現況頁看到它變了就把數字重寫一次。
    var savedCount = 0

    #if DEBUG
    /// 開發用：開「記一筆」時直接跑一次示範照片的辨識，讓截圖驗證看得到掃完的樣子。
    var demoScanOnOpen = false
    #endif
}
