import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Recibe las lecturas del iPhone y las guarda en el App Group del reloj para
/// que la app y las complicaciones las lean.
@MainActor
@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private(set) var usages: [ProviderUsage] = []
    private(set) var lastSync: Date?
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?

    override init() {
        super.init()
        reloadFromCache()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func reloadFromCache() {
        let all = UsageCache.loadAll()
        usages = ProviderID.allCases.compactMap { all[$0] }
        lastSync = UsageCache.lastRefresh
    }

    /// Pide al iPhone una lectura nueva (solo si está alcanzable).
    func requestRefresh() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            errorMessage = "El iPhone no está alcanzable ahora mismo."
            return
        }
        isRefreshing = true
        errorMessage = nil
        session.sendMessage(["action": "refresh"], replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.apply(reply)
                self?.isRefreshing = false
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = error.localizedDescription
                self?.isRefreshing = false
            }
        })
    }

    private func apply(_ payload: [String: Any]) {
        guard let data = payload["usages"] as? Data,
              let received = try? JSONDecoder().decode([ProviderUsage].self, from: data) else { return }
        for id in ProviderID.allCases where !received.contains(where: { $0.provider == id }) {
            UsageCache.remove(id)
        }
        received.forEach { UsageCache.save($0) }
        if let sentAt = payload["sentAt"] as? Double {
            UsageCache.lastRefresh = Date(timeIntervalSince1970: sentAt)
        } else {
            UsageCache.lastRefresh = Date()
        }
        reloadFromCache()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: WCSessionDelegate (llegan en hilos de fondo)

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.apply(userInfo) }
    }
}
