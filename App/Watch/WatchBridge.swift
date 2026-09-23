import Foundation
import WatchConnectivity

/// Envía la última lectura al Apple Watch y atiende sus peticiones de refresco.
///
/// El reloj no tiene los tokens (su llavero es independiente): siempre recibe
/// los datos del iPhone. Se usa `updateApplicationContext` (la última gana,
/// se entrega aunque el reloj esté dormido) y, si hay complicaciones activas,
/// una transferencia prioritaria para que se repinten.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    static let usagesKey = "usages"
    static let sentAtKey = "sentAt"

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendCurrentSnapshot() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let payload = Self.payload()
        try? session.updateApplicationContext(payload)
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(payload)
        }
    }

    static func payload() -> [String: Any] {
        let all = UsageCache.loadAll()
        let usages = ProviderID.allCases.compactMap { all[$0] }
        let data = (try? JSONEncoder().encode(usages)) ?? Data()
        return [usagesKey: data, sentAtKey: Date().timeIntervalSince1970]
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated { sendCurrentSnapshot() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        sendCurrentSnapshot()
    }

    /// El reloj pide una lectura nueva; se refresca y se responde con ella.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["action"] as? String == "refresh" else {
            replyHandler(Self.payload())
            return
        }
        Task {
            await UsageRefresher.refreshAll(allowTokenRefresh: true)
            replyHandler(Self.payload())
        }
    }
}
