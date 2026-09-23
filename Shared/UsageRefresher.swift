import Foundation
import WidgetKit

/// Orquesta una actualización completa: lee todos los proveedores conectados,
/// guarda en la caché compartida, avisa al widget y envía al ESP32.
enum UsageRefresher {
    struct Outcome: Sendable {
        var usages: [ProviderID: ProviderUsage]
        var errors: [ProviderID: String]
    }

    @discardableResult
    static func refreshAll(allowTokenRefresh: Bool, reloadWidgets: Bool = true) async -> Outcome {
        let providers = ProviderRegistry.all.filter { CredentialStore.isConnected($0.id) }
        var outcome = Outcome(usages: UsageCache.loadAll(), errors: [:])

        // Olvida lecturas de proveedores ya desconectados.
        for id in outcome.usages.keys where !providers.contains(where: { $0.id == id }) {
            outcome.usages[id] = nil
            UsageCache.remove(id)
        }

        await withTaskGroup(of: (ProviderID, Result<ProviderUsage, Error>).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return (provider.id, .success(try await provider.fetchUsage(allowTokenRefresh: allowTokenRefresh)))
                    } catch {
                        return (provider.id, .failure(error))
                    }
                }
            }
            for await (id, result) in group {
                switch result {
                case .success(let usage):
                    UsageCache.save(usage)
                    UsageCache.setError(nil, for: id)
                    outcome.usages[id] = usage
                case .failure(let error):
                    let message = error.localizedDescription
                    UsageCache.setError(message, for: id)
                    outcome.errors[id] = message
                }
            }
        }

        UsageCache.lastRefresh = Date()

        if DeviceSettings.isEnabled, !outcome.usages.isEmpty {
            await pushToDevice(outcome.usages)
        }
        if reloadWidgets {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return outcome
    }

    static func pushToDevice(_ usages: [ProviderID: ProviderUsage]) async {
        do {
            try await ESP32Client.push(usages, host: DeviceSettings.host)
            DeviceSettings.lastPushAt = Date()
            DeviceSettings.lastPushError = nil
        } catch {
            DeviceSettings.lastPushError = error.localizedDescription
        }
    }
}
