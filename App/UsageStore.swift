import Foundation
import Observation
import WidgetKit

/// Estado observable de la pantalla principal y de ajustes.
@MainActor
@Observable
final class UsageStore {
    struct Card: Identifiable {
        let provider: ProviderID
        var usage: ProviderUsage?
        var error: String?
        var id: ProviderID { provider }
    }

    struct Connection {
        var label: String?
        var source: Credential.Source
        var expiresAt: Date?
    }

    private(set) var cards: [Card] = []
    private(set) var connections: [ProviderID: Connection] = [:]
    private(set) var isRefreshing = false
    private(set) var lastRefresh: Date?

    init() {
        reloadFromCache()
    }

    /// Relee caché y credenciales sin tocar la red.
    func reloadFromCache() {
        let usages = UsageCache.loadAll()
        let errors = UsageCache.errors()
        var connections: [ProviderID: Connection] = [:]
        var cards: [Card] = []
        for provider in ProviderID.allCases {
            guard let credential = CredentialStore.load(provider) else { continue }
            connections[provider] = Connection(label: credential.accountLabel,
                                               source: credential.source,
                                               expiresAt: credential.expiresAt)
            cards.append(Card(provider: provider, usage: usages[provider], error: errors[provider]))
        }
        self.connections = connections
        self.cards = cards
        lastRefresh = UsageCache.lastRefresh
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await UsageRefresher.refreshAll(allowTokenRefresh: true)
        reloadFromCache()
        WatchBridge.shared.sendCurrentSnapshot()
    }

    /// Refresca solo si la última lectura tiene más de `maxAge` segundos.
    func refreshIfStale(maxAge: TimeInterval = 180) async {
        reloadFromCache()
        if let last = lastRefresh, Date().timeIntervalSince(last) < maxAge, !cards.contains(where: { $0.usage == nil }) {
            return
        }
        await refresh()
    }

    func disconnect(_ provider: ProviderID) {
        CredentialStore.clear(provider)
        UsageCache.remove(provider)
        reloadFromCache()
        WidgetCenter.shared.reloadAllTimelines()
        WatchBridge.shared.sendCurrentSnapshot()
    }
}
