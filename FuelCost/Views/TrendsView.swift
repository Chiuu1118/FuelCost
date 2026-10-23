import Charts
import SwiftData
import SwiftUI

/// 趨勢：一筆一筆畫出來的線，加上一條累計平均。
///
/// 圖表用系統的 Swift Charts（軸線、可及性、縮放都交給它），
/// 世界的紀律用在資料上：比自己的平均好的一筆畫大一點，
/// 差一點的畫小一點——好壞由大小承載，不靠顏色分類。
struct TrendsView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RefuelRecord.recordedAt, order: .forward) private var records: [RefuelRecord]

    @State private var metric: Metric = .economy

    enum Metric: String, CaseIterable, Identifiable {
        case economy
        case cost

        var id: String { rawValue }

        var title: String {
            switch self {
            case .economy: return "油耗"
            case .cost: return "每公里成本"
            }
        }

        var unit: String {
            switch self {
            case .economy: return "km/L"
            case .cost: return "元/km"
            }
        }

        /// 這個指標「好」是哪個方向。
        var higherIsBetter: Bool { self == .economy }

        var format: (Double) -> String {
            switch self {
            case .economy: return { DisplayFormat.economy($0) }
            case .cost: return { DisplayFormat.cost($0) }
            }
        }
    }

    private var entries: [FuelEntry] { FuelStats.entries(from: records.map(\.snapshot)) }
    private var summary: FuelSummary { FuelStats.summary(from: entries) }

    /// 每一筆在目前指標下的值。
    private var plotted: [(entry: FuelEntry, value: Double)] {
        entries.compactMap { entry in
            let value = metric == .economy ? entry.fuelEconomyKmPerL : entry.costPerKmNTD
            guard let value else { return nil }
            return (entry, value)
        }
    }

    private var average: Double? {
        switch metric {
        case .economy: return summary.averageFuelEconomyKmPerL
        case .cost: return summary.averageCostPerKmNTD
        }
    }

    private func isBetter(_ value: Double) -> Bool {
        guard let average else { return true }
        return metric.higherIsBetter ? value >= average : value <= average
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if plotted.count < 2 {
                    notEnough
                } else {
                    picker
                    chartCard
                    totals
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .background(PaperBackground())
        .navigationTitle("趨勢")
        .navigationBarTitleDisplayMode(.large)
    }

    private var picker: some View {
        Picker("看哪個", selection: $metric) {
            ForEach(Metric.allCases) { metric in
                Text(metric.title).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                FieldLabel(metric.title)
                Spacer()
                if let average {
                    Text("累計平均 \(metric.format(average)) \(metric.unit)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Marker.faded)
                }
            }

            Chart {
                if let average {
                    RuleMark(y: .value("累計平均", average))
                        .foregroundStyle(Marker.faded)
                        .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("平均 \(metric.format(average))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Marker.faded)
                        }
                }

                ForEach(plotted, id: \.entry.id) { point in
                    LineMark(
                        x: .value("日期", point.entry.snapshot.recordedAt),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Marker.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }

                ForEach(plotted, id: \.entry.id) { point in
                    PointMark(
                        x: .value("日期", point.entry.snapshot.recordedAt),
                        y: .value(metric.title, point.value)
                    )
                    .symbolSize(isBetter(point.value) ? 110 : 42)
                    .foregroundStyle(isBetter(point.value) ? Marker.red : Marker.blue.opacity(0.45))
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Marker.hair)
                    AxisValueLabel()
                        .font(.system(size: 11))
                        .foregroundStyle(Marker.faded)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Marker.hair)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(DisplayFormat.shortDay(date))
                                .font(.system(size: 10))
                                .foregroundStyle(Marker.faded)
                        }
                    }
                }
            }
            .frame(height: 230)

            HStack(spacing: 16) {
                legend(color: Marker.red, size: 11, text: "比平均好")
                legend(color: Marker.blue.opacity(0.45), size: 7, text: "比平均差")
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .cardSurface(rotation: -0.25)
    }

    private var yDomain: ClosedRange<Double> {
        let values = plotted.map(\.value)
        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }
        let padding = max((maximum - minimum) * 0.25, maximum * 0.06)
        return (minimum - padding)...(maximum + padding)
    }

    private func legend(color: Color, size: CGFloat, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Marker.faded)
        }
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel("目前為止")
            HStack(alignment: .top, spacing: 20) {
                totalFact("平均油耗", summary.averageFuelEconomyKmPerL, "km/L", Marker.red, { DisplayFormat.economy($0) })
                totalFact("每公里成本", summary.averageCostPerKmNTD, "元", Marker.blue, { DisplayFormat.cost($0) })
            }
            HStack(alignment: .top, spacing: 20) {
                totalFact("累計行駛", summary.countedDistanceKm > 0 ? summary.countedDistanceKm : nil, "km", Marker.ink, { DisplayFormat.integer($0) })
                totalFact("總油錢", summary.allAmountNTD > 0 ? summary.allAmountNTD : nil, "元", Marker.ink, { DisplayFormat.integer($0) })
            }
            Text("採計 \(summary.countedCount) 段、共 \(summary.recordCount) 筆紀錄。第一筆基準與里程倒退的都不列入平均。")
                .font(.system(size: 12))
                .foregroundStyle(Marker.faded)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .cardSurface(rotation: 0.3)
    }

    private func totalFact(_ label: String, _ value: Double?, _ unit: String, _ color: Color, _ format: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FieldLabel(label)
            MarkerValue(value: value, unit: unit, size: 26, color: color, seed: Stable.hash(value ?? 0), format: format)
        }
    }

    private var notEnough: some View {
        VStack(alignment: .leading, spacing: 14) {
            StateNote(
                symbol: records.isEmpty ? "square.dashed" : "clock",
                text: records.isEmpty ? "還沒有紀錄，所以沒有趨勢。" : "只有一筆，還沒有第二個點可以連線。",
                tone: .pending
            )
            Text("油耗是「上次加油到這次加油跑了幾公里 ÷ 這次加了幾公升」。所以趨勢要兩筆以上才畫得出來。")
                .font(.system(size: 15))
                .foregroundStyle(Marker.ink)
                .fixedSize(horizontal: false, vertical: true)
            MarkerActionButton(
                title: CameraPicker.isAvailable ? "拍油機記一筆" : "記一筆",
                systemImage: CameraPicker.isAvailable ? "camera.viewfinder" : "square.and.pencil"
            ) {
                appState.entryRoute = .new
            }
        }
        .padding(16)
        .cardSurface(rotation: -0.3)
    }
}
