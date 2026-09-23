import SwiftUI

@main
struct PersonalLimitsWatchApp: App {
    @State private var session = WatchSessionManager.shared

    init() {
        WatchSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environment(session)
        }
    }
}
