import SwiftUI

@main
struct PersonalLimitsApp: App {
    @State private var store = UsageStore()
    @State private var ads = AdsManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Debe registrarse antes de que termine el arranque.
        BackgroundRefresh.register()
        WatchBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(store)
                .environment(ads)
                .task { await ads.prepare() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await store.refreshIfStale() }
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}
