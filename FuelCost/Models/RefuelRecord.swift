import Foundation
import SwiftData

/// 一次加油。只有四個事實：什麼時候、當時里程多少、花了多少錢、加了多少油。
@Model
final class RefuelRecord {
    /// 給 SwiftUI 與統計用的穩定識別；SwiftData 的 persistentModelID 不適合外流。
    @Attribute(.unique) var uuid: UUID

    /// 加油當下的時間。
    var recordedAt: Date

    /// 加油當下的儀表板總里程（公里）。
    var odometerKm: Double

    /// 這次付掉的油錢（新台幣）。
    var amountNTD: Double

    /// 這次加的公升數。
    var liters: Double

    /// 油機照片的檔名；存在 app 自己的容器裡，不會進相簿。
    var photoFileName: String?

    /// 建檔時間，用來決定同一時間戳記下的先後。
    var createdAt: Date

    init(
        uuid: UUID = UUID(),
        recordedAt: Date = .now,
        odometerKm: Double,
        amountNTD: Double,
        liters: Double,
        photoFileName: String? = nil,
        createdAt: Date = .now
    ) {
        self.uuid = uuid
        self.recordedAt = recordedAt
        self.odometerKm = odometerKm
        self.amountNTD = amountNTD
        self.liters = liters
        self.photoFileName = photoFileName
        self.createdAt = createdAt
    }
}

extension RefuelRecord {
    /// 統計引擎只吃這個沒有 SwiftData 依賴的形狀，所以計算邏輯可以單獨驗證。
    var snapshot: RefuelSnapshot {
        RefuelSnapshot(
            id: uuid,
            recordedAt: recordedAt,
            odometerKm: odometerKm,
            amountNTD: amountNTD,
            liters: liters
        )
    }
}
