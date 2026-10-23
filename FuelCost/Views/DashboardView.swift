import SwiftData
import SwiftUI

/// 現況：一眼看到累計平均油耗，下面是最近幾筆。
///
/// 這一頁的順序是刻意的：狀態 → 記帳板 → 最新一筆 → 最近幾筆 → 主要動作。
/// 使用者站在加油島旁邊打開它，要看的東西不該要滑。
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \RefuelRecord.recordedAt, order: .forward) private var records: [RefuelRecord]

    private var snapshotList: [RefuelSnapshot] { records.map(\.snapshot) }
    private var entries: [FuelEntry] { FuelStats.entries(from: snapshotList) }
    private var summary: FuelSummary { FuelStats.summary(from: entries) }

    /// 最近幾筆，新的在上面。
    private var recentEntries: [FuelEntry] {
        Array(entries.suffix(3).reversed())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StampRow(summary: summary)
                stateNote
                board
                if let latest = summary.latestEntry {
                    LatestCard(entry: latest)
                }
                recentSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(PaperBackground())
        .navigationTitle("油錢計算")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
    }

    // MARK: - 狀態

    private var stateNote: some View {
        StateNote(symbol: note.symbol, text: note.text, tone: note.tone)
    }

    private var note: (symbol: String, text: String, tone: StateNote.Tone) {
        switch summary.readiness {
        case .noRecords:
            return ("square.dashed", "還沒有紀錄。第一次加油記一筆當基準，下一次就能算出油耗。", .pending)
        case .waitingForSecondRecord:
            return ("clock", "目前只有一筆基準，還沒有里程差可以算油耗。", .pending)
        case .latestOdometerWentBackwards:
            return ("exclamationmark.triangle.fill", "最新一筆的里程比上一筆低，那一筆不算。下面的平均不含它。", .problem)
        case .someRecordsExcluded(let count):
            return (
                "exclamationmark.triangle.fill",
                "有 \(count) 筆的里程比上一筆低，不列入平均。緊接在它後面那一段，是從那個里程算起的。",
                .problem
            )
        case .ready:
            return ("checkmark.seal.fill", "累計 \(summary.countedCount) 段里程可採計。第一筆基準不列入平均。", .note)
        }
    }

    // MARK: - 記帳板

    @ViewBuilder
    private var board: some View {
        if summary.readiness == .noRecords {
            emptyBoard
        } else {
            filledBoard
        }
    }

    /// 記帳板上的大字是自己畫的，會跟著動態字級長大，但旁邊的文字是固定尺寸，
    /// 所以放到最大時一定會擠出去。這裡把兩張卡的上限鎖在 accessibility1：
    /// 字級放大時仍然放大，但不會大到把版面撐破。
    private var boardTypeLimit: DynamicTypeSize { .accessibility1 }

    private var emptyBoard: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("累計平均油耗")
            Text("這裡會寫上你的平均油耗")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Marker.faded)
            HandLine(seed: 12, amplitude: 1.6)
                .stroke(Marker.hair, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5]))
                .frame(height: 5)
            Text("每一次都加滿 95，公升數就等於上一段跑的油。所以第一筆當基準，第二筆開始就有數字。")
                .font(.system(size: 13))
                .foregroundStyle(Marker.faded)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface(rotation: -0.3)
    }

    private var filledBoard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                FieldLabel("累計平均油耗")
                Spacer()
                Text("\(summary.countedCount) 段里程")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Marker.faded)
            }

            ZStack(alignment: .topLeading) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    MarkerNumber(
                        text: summary.averageFuelEconomyKmPerL.map { DisplayFormat.economy($0) } ?? "",
                        size: 74,
                        color: Marker.red,
                        seed: summary.countedCount,
                        writesOnAppear: true
                    )
                    Text("km/L")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Marker.red)
                }
                if summary.readiness == .latestOdometerWentBackwards {
                    HandStrike(color: Marker.red, seed: summary.countedCount)
                        .frame(width: 250, height: 92)
                        .offset(x: 4, y: -6)
                }
            }

            HandUnderline(color: Marker.red, seed: summary.countedCount &+ 5)
                .frame(width: 232, height: 12)
                .padding(.top, -6)

            HStack(alignment: .top, spacing: 22) {
                boardFact(
                    label: "每公里成本",
                    value: summary.averageCostPerKmNTD.map { DisplayFormat.cost($0) } ?? nil,
                    unit: "元",
                    size: 26,
                    color: Marker.blue
                )
                boardFact(
                    label: "累計行駛",
                    value: summary.countedDistanceKm > 0 ? DisplayFormat.km(summary.countedDistanceKm) : nil,
                    unit: "km",
                    size: 26,
                    color: Marker.blue
                )
            }
            .padding(.top, 8)

            Text("總共 \(DisplayFormat.money(summary.allAmountNTD)) 元、\(DisplayFormat.liters(summary.allLiters)) 公升，\(summary.recordCount) 筆紀錄。")
                .font(.system(size: 12))
                .foregroundStyle(Marker.faded)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface(rotation: -0.35)
        .dynamicTypeSize(...boardTypeLimit)
    }

    private func boardFact(label: String, value: String?, unit: String, size: CGFloat, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FieldLabel(label)
            if let value {
                MarkerMeasurement(value: value, unit: unit, size: size, color: color, seed: Stable.hash(value))
            } else {
                Text("—")
                    .font(.system(size: size * 0.62, weight: .bold))
                    .foregroundStyle(Marker.faded)
            }
        }
    }

    // MARK: - 最近幾筆

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                FieldLabel("最近幾筆")
                Spacer()
                if records.count > 3 {
                    Button {
                        appState.selectedTab = .history
                    } label: {
                        Text("全部 \(records.count) 筆")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Marker.blue)
                            // 文字本身只有 16pt 高，補到 44pt 才好按。
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }
            }

            if recentEntries.isEmpty {
                Text("記滿一筆就會出現在這裡。")
                    .font(.system(size: 14))
                    .foregroundStyle(Marker.faded)
            } else {
                ForEach(recentEntries) { entry in
                    RecordRowCard(entry: entry, compact: true)
                }
            }
        }
    }

    // MARK: - 主要動作

    private var actionBar: some View {
        VStack(spacing: 0) {
            MarkerActionButton(
                title: CameraPicker.isAvailable ? "拍油機記一筆" : "記一筆",
                systemImage: CameraPicker.isAvailable ? "camera.viewfinder" : "square.and.pencil"
            ) {
                appState.entryRoute = .new
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(.bar)
    }
}

/// 抬頭那一行：這個 app 只服務一種情況——固定加 95 加滿。
private struct StampRow: View {
    let summary: FuelSummary

    var body: some View {
        HStack(spacing: 10) {
            MarkerStamp(text: "95 加滿")
            if let latest = summary.latestOdometerKm {
                Text("上次 \(DisplayFormat.km(latest)) km")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Marker.faded)
            }
            Spacer()
        }
    }
}

/// 最新一筆：里程寫大，旁邊一行旁註說這次跑了多少。
private struct LatestCard: View {
    let entry: FuelEntry

    private var rotation: Double {
        let seed = abs(Stable.hash(entry.id.uuidString) % 1000)
        return (Double(seed) / 1000.0 - 0.5) * 0.8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                FieldLabel("最新一筆")
                Spacer()
                Text(DisplayFormat.day(entry.snapshot.recordedAt))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Marker.faded)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                MarkerNumber(
                    text: DisplayFormat.km(entry.snapshot.odometerKm),
                    size: 40,
                    color: Marker.ink,
                    seed: Stable.hash(entry.snapshot.odometerKm) &+ 11
                )
                Text("km")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Marker.faded)
                Spacer(minLength: 8)
                MarkerValue(
                    value: entry.fuelEconomyKmPerL,
                    unit: "km/L",
                    size: 28,
                    color: entry.countsTowardAverages ? Marker.red : Marker.faded,
                    seed: Stable.hash(entry.snapshot.odometerKm) &+ 7,
                    format: { DisplayFormat.economy($0) }
                )
            }

            Text("油錢 \(DisplayFormat.money(entry.snapshot.amountNTD)) 元 ・ \(DisplayFormat.liters(entry.snapshot.liters)) 公升")
                .font(.system(size: 14))
                .foregroundStyle(Marker.ink)

            if let distance = entry.distanceKm {
                Text("上次到這次跑了 \(DisplayFormat.km(distance)) km。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Marker.blue)
            } else if entry.odometerWentBackwards {
                Text("里程比上一筆低，這一筆不算進平均。")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Marker.red)
            } else {
                Text("這是第一筆基準，還沒有里程差。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Marker.faded)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .cardSurface(rotation: rotation)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
