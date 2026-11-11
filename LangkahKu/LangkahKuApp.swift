import SwiftUI

@main
struct LangkahKuApp: App {
    @StateObject private var store = PedometerStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            StepCounterView(store: store)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        store.refreshAuthorizationAndData()
                    }
                }
        }
    }
}
