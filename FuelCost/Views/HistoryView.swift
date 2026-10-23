import SwiftData
import SwiftUI

/// 紀錄：全部的一筆一筆，照月份分成一疊一疊。
///
/// 列表用原生 List，所以滑動刪除、選取、捲動都是系統行為。
/// 世界只出現在每一張卡的內容裡。
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \RefuelRecord.recordedAt, order: .forward) private var records: [RefuelRecord]

    @State private var path: [UUID] = []
    @State private var pendingDeletion: RefuelRecord?
    @State private var deleteError: String?

    private var entriesNewestFirst: [FuelEntry] {
        FuelStats.entries(from: records.map(\.snapshot)).reversed()
    }

    private var months: [(key: String, entries: [FuelEntry])] {
        var order: [String] = []
        var buckets: [String: [FuelEntry]] = [:]
        for entry in entriesNewestFirst {
            let key = DisplayFormat.month(entry.snapshot.recordedAt)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(entry)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if records.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .background(PaperBackground())
            .navigationTitle("紀錄")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { id in
                if let record = records.first(where: { $0.uuid == id }) {
                    RecordDetailView(record: record)
                }
            }
            .confirmationDialog(
                "要刪掉這一筆嗎？",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("刪除", role: .destructive) {
                    if let record = pendingDeletion { delete(record) }
                    pendingDeletion = nil
                }
                Button("取消", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text(pendingDeletion.map { "\(DisplayFormat.day($0.recordedAt)) ・ \(DisplayFormat.km($0.odometerKm)) km" } ?? "")
            }
            .alert("刪除失敗", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("好") { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(months, id: \.key) { month in
                Section {
                    ForEach(month.entries) { entry in
                        Button {
                            path.append(entry.id)
                        } label: {
                            RecordRowCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = records.first { $0.uuid == entry.id }
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    monthHeader(month.key)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func monthHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Marker.blue)
                .textCase(nil)
            HandLine(seed: Stable.hash(title), amplitude: 1.2)
                .stroke(Marker.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(height: 4)
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
    }

    private var empty: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                StateNote(symbol: "square.dashed", text: "還沒有任何紀錄。", tone: .pending)
                Text("第一次加油記一筆當基準。第二次加油再記一筆，就會出現平均油耗與每公里成本。")
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
            .padding(.horizontal, 18)
        }
    }

    private func delete(_ record: RefuelRecord) {
        context.delete(record)
        do {
            try context.save()
        } catch {
            // 存不回去就別把照片也刪了，不然連救都救不回來。
            deleteError = "刪不掉：\(error.localizedDescription)"
            return
        }
        if let photo = record.photoFileName { PhotoStore.delete(photo) }
    }
}
