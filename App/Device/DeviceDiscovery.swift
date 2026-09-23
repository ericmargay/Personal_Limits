import Foundation
import Network
import Observation

/// Busca ESP32 que anuncien `_limits._tcp` por Bonjour en la red local.
@MainActor
@Observable
final class DeviceDiscovery {
    struct Found: Identifiable, Hashable {
        let name: String
        var id: String { name }
        /// El firmware usa el mismo nombre como hostname mDNS.
        var host: String { "\(name).local" }
    }

    private(set) var devices: [Found] = []
    private(set) var isBrowsing = false
    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: AppConfig.deviceServiceType, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { results, _ in
            let names = results.compactMap { result -> String? in
                if case let .service(name, _, _, _) = result.endpoint { return name }
                return nil
            }
            Task { @MainActor in
                self.devices = Set(names).sorted().map(Found.init)
            }
        }
        browser.stateUpdateHandler = { state in
            Task { @MainActor in
                switch state {
                case .ready: self.isBrowsing = true
                case .failed, .cancelled: self.isBrowsing = false
                default: break
                }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
        isBrowsing = true
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
    }
}
