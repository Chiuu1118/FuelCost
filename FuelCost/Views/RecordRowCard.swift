import SwiftData
import SwiftUI

/// 一筆紀錄變成一張卡。
///
/// 客廳版（緊湊）給現況頁的最近幾筆用，完整版給紀錄頁用。
/// 兩種共用同一個寫法：里程用麥克筆寫，油錢與公升數是印刷的小字。
struct RecordRowCard: View {
    let entry: FuelEntry
    var compact = false
    var showsDate = true

    /// 每一張卡歪的角度都不一樣，但都由 id 決定——同一個畫面重畫一百次都一樣歪。
    private var rotation: Double {
        let seed = abs(Stable.hash(entry.id.uuidString) % 1000)
        return (Double(seed) / 1000.0 - 0.5) * 0.7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 9) {
            HStack(alignment: .firstTextBaseline) {
                if showsDate {
                    FieldLabel(DisplayFormat.day(entry.snapshot.recordedAt), color: Marker.faded)
                }
                Spacer(minLength: 8)
                if entry.odometerWentBackwards {
                    MarkerStamp(text: "里程倒退", color: Marker.red, rotation: 1.2)
                } else if !entry.countsTowardAverages {
                    MarkerStamp(text: "基準", color: Marker.faded, rotation: -1.2)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                MarkerNumber(
                    text: DisplayFormat.km(entry.snapshot.odometerKm),
                    size: compact ? 27 : 33,
                    color: Marker.ink,
                    seed: Stable.hash(entry.snapshot.odometerKm)
                )
                Text("km")
                    .font(.system(size: compact ? 12 : 13, weight: .bold))
                    .foregroundStyle(Marker.faded)

                Spacer(minLength: 10)

                MarkerValue(
                    value: entry.fuelEconomyKmPerL,
                    unit: "km/L",
                    size: compact ? 24 : 30,
                    color: entry.countsTowardAverages ? Marker.red : Marker.faded,
                    seed: Stable.hash(entry.snapshot.odometerKm) &+ 3,
                    format: { DisplayFormat.economy($0) }
                )
            }

            HStack(spacing: 12) {
                labelled("油錢", DisplayFormat.money(entry.snapshot.amountNTD), "元")
                labelled("公升", DisplayFormat.liters(entry.snapshot.liters), "L")
                labelled("單價", entry.unitPriceNTD.map { DisplayFormat.unitPrice($0) } ?? "—", "元")
            }

            if !compact, let note = marginNote {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: note.symbol)
                        .font(.system(size: 11, weight: .bold))
                    Text(note.text)
                        .font(.system(size: 13, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(note.color)
            }
        }
        .padding(compact ? 12 : 15)
        .cardSurface(rotation: compact ? 0 : rotation)
        .accessibilityElement(children: .combine)
    }

    /// 這張卡下面那行旁註：這次跑了多少、平均是多少。
    private var marginNote: (symbol: String, text: String, color: Color)? {
        if entry.odometerWentBackwards {
            return ("exclamationmark.triangle.fill", "里程比上一筆低，這一筆不算進平均。", Marker.red)
        }
        guard let distance = entry.distanceKm else {
            return ("flag.fill", "第一筆是基準，用來對下一次的里程。", Marker.faded)
        }
        guard let previous = entry.previousOdometerKm, let economy = entry.fuelEconomyKmPerL else { return nil }
        return (
            "arrow.left.and.right",
            "上次 \(DisplayFormat.km(previous)) km 到這次跑了 \(DisplayFormat.km(distance)) km，這次 \(DisplayFormat.economy(economy)) km/L。",
            Marker.blue
        )
    }

    private func labelled(_ title: String, _ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Marker.faded)
            Text(value)
                .font(.system(size: compact ? 14 : 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Marker.ink)
            Text(unit)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Marker.faded)
        }
    }
}
