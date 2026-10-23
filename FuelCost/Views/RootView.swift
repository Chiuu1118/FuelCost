import SwiftData
import SwiftUI

/// App 的外殼：三個原生分頁，加上「記一筆」這張表。
///
/// 分頁列、navigation bar、sheet 全部交給系統。世界只活在內容裡。
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RefuelRecord.recordedAt, order: .forward) private var records: [RefuelRecord]
    @State private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Tab("現況", systemImage: "fuelpump.fill", value: AppState.Tab.dashboard) {
                NavigationStack {
                    DashboardView()
                }
            }
            Tab("紀錄", systemImage: "list.bullet.rectangle", value: AppState.Tab.history) {
                NavigationStack {
                    HistoryView()
                }
            }
            Tab("趨勢", systemImage: "chart.xyaxis.line", value: AppState.Tab.trends) {
                NavigationStack {
                    TrendsView()
                }
            }
        }
        .tint(Marker.blue)
        .sheet(item: $appState.entryRoute) { route in
            // 明確注入：sheet 的內容是另一棵樹，只靠外層的 .environment 不一定拿得到。
            RecordEntryView(route: route)
                .environment(appState)
        }
        .environment(appState)
        .task {
            #if DEBUG
            DevelopmentSupport.handleLaunchArguments(context: context, existing: records)
            DevelopmentSupport.applyLaunchArguments(appState: appState)
            #endif
        }
    }
}

#if DEBUG
#Preview("有資料") {
    RootView().modelContainer(SampleData.previewContainer())
}
#endif

#Preview("空的") {
    RootView()
        .modelContainer(for: RefuelRecord.self, inMemory: true)
}
