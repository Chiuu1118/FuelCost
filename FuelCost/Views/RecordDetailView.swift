import SwiftData
import SwiftUI

/// 一筆紀錄的全部：拍的那張照片、四個值、以及由它們算出來的東西。
struct RecordDetailView: View {
    let record: RefuelRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \RefuelRecord.recordedAt, order: .forward) private var allRecords: [RefuelRecord]

    @State private var showsPhoto = false
    @State private var confirmsDeletion = false
    @State private var deleteError: String?

    private var snapshotList: [RefuelSnapshot] { allRecords.map(\.snapshot) }

    private var entry: FuelEntry? {
        FuelStats.entries(from: snapshotList).first { $0.id == record.uuid }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = photo {
                    photoBlock(image)
                }
                facts
                derived
                actions
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(PaperBackground())
        .navigationTitle(DisplayFormat.day(record.recordedAt))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("改一筆") { appState.entryRoute = .edit(record) }
            }
        }
        .sheet(isPresented: $showsPhoto) {
            if let image = photo { PhotoViewer(image: image) }
        }
        .confirmationDialog("要刪掉這一筆嗎？", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("刪除", role: .destructive) { delete() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("刪掉之後，平均油耗會重新算。")
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

    private var photo: UIImage? {
        guard let name = record.photoFileName else { return nil }
        return PhotoStore.load(name)
    }

    private func photoBlock(_ image: UIImage) -> some View {
        Button {
            showsPhoto = true
        } label: {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 190)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Label("看大張", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(Marker.ink)
                        .padding(8)
                }
        }
        .buttonStyle(MarkerPressStyle())
        .accessibilityLabel("加油時拍的照片，點一下看大張")
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                MarkerNumber(
                    text: DisplayFormat.km(record.odometerKm),
                    size: 38,
                    color: Marker.ink,
                    seed: Stable.hash(record.odometerKm)
                )
                Text("km")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Marker.faded)
                Spacer()
                if entry?.countsTowardAverages == false {
                    MarkerStamp(
                        text: entry?.odometerWentBackwards == true ? "里程倒退" : "基準",
                        color: entry?.odometerWentBackwards == true ? Marker.red : Marker.faded,
                        rotation: 1.3
                    )
                }
            }

            HandLine(seed: Stable.hash(record.odometerKm), amplitude: 1.4)
                .stroke(Marker.hair, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(height: 4)

            factLine("油錢", "\(DisplayFormat.money(record.amountNTD)) 元")
            factLine("公升數", "\(DisplayFormat.liters(record.liters)) L")
            factLine("單價", entry?.unitPriceNTD.map { "\(DisplayFormat.unitPrice($0)) 元" } ?? "—")
            factLine("日期", DisplayFormat.day(record.recordedAt))
            factLine("上一筆里程", entry?.previousOdometerKm.map { "\(DisplayFormat.km($0)) km" } ?? "這是第一筆")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .cardSurface(rotation: 0.25)
    }

    private var derived: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("這一筆算出來的")
            HStack(alignment: .top, spacing: 20) {
                derivedFact("跑了", entry?.distanceKm, "km", Marker.ink, 26)
                derivedFact("油耗", entry?.fuelEconomyKmPerL, "km/L", Marker.red, 26)
                derivedFact("每公里", entry?.costPerKmNTD, "元", Marker.blue, 26)
            }
            if entry?.odometerWentBackwards == true {
                StateNote(
                    symbol: "exclamationmark.triangle.fill",
                    text: "里程比上一筆低，這一筆不算進平均。改一筆修正它。",
                    tone: .problem
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .cardSurface(rotation: -0.2)
    }

    private func derivedFact(_ label: String, _ value: Double?, _ unit: String, _ color: Color, _ size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FieldLabel(label)
            MarkerValue(
                value: value,
                unit: unit,
                size: size,
                color: color,
                seed: Stable.hash(value ?? 0),
                format: { unit == "km" ? DisplayFormat.integer($0) : DisplayFormat.decimals($0, 2) }
            )
        }
    }

    private func factLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Marker.faded)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Marker.ink)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            MarkerSecondaryButton(title: "改一筆", systemImage: "pencil") {
                appState.entryRoute = .edit(record)
            }
            Button(role: .destructive) {
                confirmsDeletion = true
            } label: {
                Label("刪掉這一筆", systemImage: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
        }
    }

    private func delete() {
        context.delete(record)
        do {
            try context.save()
        } catch {
            // 存不回去就別把照片也刪了，不然連救都救不回來。
            deleteError = "刪不掉：\(error.localizedDescription)"
            return
        }
        if let name = record.photoFileName { PhotoStore.delete(name) }
        dismiss()
    }
}

/// 看大張：只做一件事，所以不需要別的東西。
private struct PhotoViewer: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }
}
