import SwiftData
import SwiftUI

/// 記一筆。使用者站在加油島旁邊，單手、二十秒內要完成的事。
///
/// 流程是：拍油機（或不拍）→ 金額與公升數被帶進來 → 打當前里程 → 存。
/// 里程是唯一一定要自己打的值，所以掃完之後游標直接停在那一格。
struct RecordEntryView: View {
    let route: AppState.EntryRoute

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \RefuelRecord.recordedAt, order: .forward) private var records: [RefuelRecord]

    @State private var draft = RecordDraft()
    @State private var scanner = ScanController()
    @State private var pickedImage: UIImage?
    /// 這次有沒有真的換照片。改里程、油錢不該重寫一張 JPEG。
    @State private var photoChanged = false
    /// 存檔失敗時要說出來，不能安靜地當成存好了。
    @State private var saveError: String?
    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var didLoad = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case odometer
        case amount
        case liters
    }

    private var isNew: Bool {
        if case .new = route { return true }
        return false
    }

    private var editingRecord: RefuelRecord? {
        if case .edit(let record) = route { return record }
        return nil
    }

    /// 這一筆的上一筆里程。改一筆的時候要把自己排除掉。
    private var previousOdometer: Double? {
        let candidates = records.filter { $0.uuid != editingRecord?.uuid }
        return FuelStats.previousOdometer(before: draft.recordedAt, in: candidates.map(\.snapshot))
    }

    private var odometerProblem: String? {
        draft.odometerProblem(previousOdometerKm: previousOdometer)
    }

    private var canSave: Bool {
        // 畫面上已經在抱怨的欄位問題（0 公升、負數…）也要擋住存檔，
        // 不然會出現「紅字寫著公升數要是正的，存檔卻是可按的」。
        draft.canSave && odometerProblem == nil && draft.fieldProblems().isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    scanBlock
                    fieldsBlock
                    previewBlock
                    problems
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(PaperBackground())
            .navigationTitle(isNew ? "記一筆" : "改一筆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("存檔") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showsLibrary) {
                PhotoLibraryPicker { image in handle(image) }
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraPicker { image in handle(image) }
                    .ignoresSafeArea()
            }
            .onChange(of: scanner.phase) { _, phase in
                guard phase == .finished, let reading = scanner.outcome?.reading else { return }
                draft.apply(reading)
                // 掃完就把游標放到里程，因為那是使用者唯一還缺的值。
                if draft.odometerText.isEmpty { focus = .odometer }
            }
            .task {
                guard !didLoad else { return }
                didLoad = true
                if let record = editingRecord {
                    draft.odometerText = DisplayFormat.decimalString(record.odometerKm)
                    draft.amountText = DisplayFormat.decimalString(record.amountNTD)
                    draft.litersText = DisplayFormat.decimalString(record.liters, places: 2)
                    draft.recordedAt = record.recordedAt
                    draft.photoFileName = record.photoFileName
                    if let name = record.photoFileName { pickedImage = PhotoStore.load(name) }
                }
                #if DEBUG
                if appState.demoScanOnOpen {
                    appState.demoScanOnOpen = false
                    handle(DevelopmentSupport.demoPumpImage())
                }
                #endif
            }
        }
    }

    // MARK: - 拍照

    private var scanBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel("油機上的數字")

            if let image = pickedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 132)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        statusBadge
                            .padding(8)
                    }
            }

            switch scanner.phase {
            case .scanning:
                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在讀油機上的數字…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Marker.ink)
                }
            case .failed(let message):
                StateNote(symbol: "exclamationmark.triangle.fill", text: message, tone: .problem)
            case .finished:
                VStack(alignment: .leading, spacing: 7) {
                    if let summary = scanner.summaryText {
                        StateNote(
                            symbol: scanner.outcome?.reading.isComplete == true ? "checkmark.seal.fill" : "questionmark.circle",
                            text: summary,
                            tone: scanner.outcome?.reading.isComplete == true ? .note : .pending
                        )
                    }
                    ForEach(draft.scanNotes, id: \.self) { note in
                        Text("・\(note)")
                            .font(.system(size: 12))
                            .foregroundStyle(Marker.faded)
                    }
                }
            case .idle:
                EmptyView()
            }

            if !draft.scanWarnings.isEmpty {
                ForEach(draft.scanWarnings, id: \.self) { warning in
                    StateNote(symbol: "exclamationmark.triangle.fill", text: warning, tone: .problem)
                }
            }

            HStack(spacing: 10) {
                if CameraPicker.isAvailable {
                    MarkerSecondaryButton(title: "拍油機", systemImage: "camera.viewfinder") {
                        showsCamera = true
                    }
                }
                MarkerSecondaryButton(title: pickedImage == nil ? "從相簿選" : "換一張", systemImage: "photo.on.rectangle") {
                    showsLibrary = true
                }
            }

            if pickedImage == nil {
                Button {
                    focus = .odometer
                } label: {
                    Text("不拍，直接手打")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Marker.blue)
                        // 文字本身只有 16pt 高，補到 44pt 才好按。
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .cardSurface(rotation: -0.25)
    }

    private var statusBadge: some View {
        Text(scanner.phase.isBusy ? "讀取中" : "這次的照片")
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .foregroundStyle(Marker.ink)
    }

    // MARK: - 四個欄位

    private var fieldsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            numberField(
                title: "當前里程",
                unit: "km",
                placeholder: previousOdometer.map { "上次 \(DisplayFormat.km($0))" } ?? "例：45210",
                text: $draft.odometerText,
                field: .odometer,
                emphasizes: true
            )

            HandLine(seed: 3, amplitude: 1.2)
                .stroke(Marker.hair, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(height: 4)

            numberField(
                title: "油錢",
                unit: "元",
                placeholder: "例：1024",
                text: $draft.amountText,
                field: .amount
            )

            numberField(
                title: "公升數",
                unit: "L",
                placeholder: "例：32.40",
                text: $draft.litersText,
                field: .liters
            )

            HandLine(seed: 9, amplitude: 1.2)
                .stroke(Marker.hair, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(height: 4)

            HStack {
                FieldLabel("日期")
                Spacer()
                DatePicker("日期", selection: $draft.recordedAt, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_TW"))
            }
        }
        .padding(15)
        .cardSurface(rotation: 0.2)
    }

    private func numberField(
        title: String,
        unit: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        emphasizes: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                FieldLabel(title, color: emphasizes ? Marker.blue : Marker.faded)
                Spacer()
                Text(unit)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Marker.faded)
            }
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: emphasizes ? 30 : 24, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Marker.ink)
                .focused($focus, equals: field)
                .submitLabel(.next)
                .onSubmit { advance(from: field) }
                .accessibilityLabel(title)
        }
    }

    private func advance(from field: Field) {
        switch field {
        case .odometer: focus = .amount
        case .amount: focus = .liters
        case .liters: focus = nil
        }
    }

    // MARK: - 即時重算

    private var previewBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("這一筆會是")

            if let preview = draft.preview(previousOdometerKm: previousOdometer) {
                HStack(alignment: .top, spacing: 22) {
                    previewFact("跑了", DisplayFormat.integer(preview.distanceKm), "km", Marker.ink, 27)
                    previewFact("油耗", DisplayFormat.economy(preview.fuelEconomy), "km/L", Marker.red, 27)
                    previewFact("每公里", DisplayFormat.cost(preview.costPerKm), "元", Marker.blue, 22)
                }
                Text("里程打到哪，這裡就重算到哪。存下去才會寫進平均值。")
                    .font(.system(size: 12))
                    .foregroundStyle(Marker.faded)
            } else {
                Text("填了里程就會當場算出來。油耗是「上次到這次跑了幾公里 ÷ 這次加了幾公升」。")
                    .font(.system(size: 14))
                    .foregroundStyle(Marker.faded)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .cardSurface(rotation: -0.15)
    }

    private func previewFact(_ label: String, _ value: String, _ unit: String, _ color: Color, _ size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FieldLabel(label)
            MarkerMeasurement(value: value, unit: unit, size: size, color: color)
        }
    }

    // MARK: - 有問題的地方

    @ViewBuilder
    private var problems: some View {
        if let saveError {
            StateNote(symbol: "externaldrive.badge.xmark", text: saveError, tone: .problem)
        }
        if let odometerProblem {
            StateNote(symbol: "exclamationmark.triangle.fill", text: odometerProblem, tone: .problem)
        }
        ForEach(draft.fieldProblems(), id: \.self) { problem in
            StateNote(symbol: "exclamationmark.circle", text: problem, tone: .problem)
        }
    }

    // MARK: - 動作

    private func handle(_ image: UIImage) {
        pickedImage = image
        // 只有使用者這次真的拍／選了一張，才算換過照片。
        photoChanged = true
        scanner.scan(image)
    }

    private func save() {
        guard let odometer = draft.odometerKm,
              let amount = draft.amountNTD,
              let liters = draft.liters else { return }

        // 存不起來就別說存好了：照片留著、畫面留著、把原因講出來。
        var newPhotoName: String?
        if photoChanged, let image = pickedImage {
            do {
                newPhotoName = try PhotoStore.save(image)
            } catch {
                saveError = "照片存不起來，其他的都還在。"
                return
            }
        }

        switch route {
        case .new:
            let record = RefuelRecord(
                recordedAt: draft.recordedAt,
                odometerKm: odometer,
                amountNTD: amount,
                liters: liters,
                photoFileName: newPhotoName
            )
            context.insert(record)

        case .edit(let record):
            record.recordedAt = draft.recordedAt
            record.odometerKm = odometer
            record.amountNTD = amount
            record.liters = liters
            // 只有在這次真的換了一張照片的時候才動照片。
            if let saved = newPhotoName {
                if let old = record.photoFileName, old != saved { PhotoStore.delete(old) }
                record.photoFileName = saved
            }
        }

        do {
            try context.save()
        } catch {
            saveError = "存不進去：\(error.localizedDescription)"
            return
        }

        appState.savedCount += 1
        dismiss()
    }
}
