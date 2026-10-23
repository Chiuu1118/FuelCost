import SwiftUI
import SwiftData

@main
struct FuelCostApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: RefuelRecord.self)
    }
}
