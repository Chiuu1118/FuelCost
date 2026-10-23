import Foundation
import SwiftUI

/// 拍照辨識的狀態機。辨識很花時間，所以它有自己的狀態，
/// 畫面只要照著狀態說話就好，不要自己猜現在在做什麼。
@MainActor
@Observable
final class ScanController {

    enum Phase: Equatable {
        case idle
        case scanning
        case finished
        case failed(String)

        var isBusy: Bool { self == .scanning }
    }

    private(set) var phase: Phase = .idle
    private(set) var outcome: FuelScanOutcome?

    /// 開始辨識。這個方法會立刻回來，結果晚點放進 `outcome`。
    func scan(_ image: UIImage) {
        phase = .scanning
        outcome = nil

        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<FuelScanOutcome, Error> in
                do {
                    return .success(try ReceiptScanner.scan(image: image))
                } catch {
                    return .failure(error)
                }
            }.value

            switch result {
            case .success(let outcome):
                self.outcome = outcome
                self.phase = .finished
            case .failure(let error):
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.phase = .failed(message)
            }
        }
    }

    func reset() {
        phase = .idle
        outcome = nil
    }

    /// 給畫面用的一句話，說明這次辨識到底讀到了什麼。
    var summaryText: String? {
        guard let reading = outcome?.reading else { return nil }
        switch reading.confidence {
        case .labeled:
            return "照片上寫得清清楚楚。"
        case .inferred:
            return "沒有標籤，靠單價和公升數對出來的。"
        case .none:
            return "讀不出金額與公升數，自己填比較快。"
        }
    }
}
