import Foundation

enum SharedDefaults {
    static let store: UserDefaults = UserDefaults(suiteName: AppConfig.appGroup) ?? .standard
}

/// Última lectura correcta por proveedor, compartida con el widget a través del
/// App Group para que pueda pintarse al instante y sin red.
enum UsageCache {
    private static let usagesKey = "usages.v1"
    private static let errorsKey = "errors.v1"
    private static let lastRefreshKey = "lastRefresh.v1"

    static func loadAll() -> [ProviderID: ProviderUsage] {
        guard let data = SharedDefaults.store.data(forKey: usagesKey),
              let raw = try? JSONDecoder().decode([String: ProviderUsage].self, from: data) else {
            return [:]
        }
        var result: [ProviderID: ProviderUsage] = [:]
        for (key, value) in raw {
            if let id = ProviderID(rawValue: key) { result[id] = value }
        }
        return result
    }

    static func load(_ provider: ProviderID) -> ProviderUsage? {
        loadAll()[provider]
    }

    static func save(_ usage: ProviderUsage) {
        var all = loadAll()
        all[usage.provider] = usage
        persist(all)
    }

    static func remove(_ provider: ProviderID) {
        var all = loadAll()
        all[provider] = nil
        persist(all)
        setError(nil, for: provider)
    }

    private static func persist(_ all: [ProviderID: ProviderUsage]) {
        let raw = Dictionary(uniqueKeysWithValues: all.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        SharedDefaults.store.set(data, forKey: usagesKey)
    }

    static func errors() -> [ProviderID: String] {
        guard let raw = SharedDefaults.store.dictionary(forKey: errorsKey) as? [String: String] else { return [:] }
        var result: [ProviderID: String] = [:]
        for (key, value) in raw {
            if let id = ProviderID(rawValue: key) { result[id] = value }
        }
        return result
    }

    static func setError(_ message: String?, for provider: ProviderID) {
        var raw = (SharedDefaults.store.dictionary(forKey: errorsKey) as? [String: String]) ?? [:]
        raw[provider.rawValue] = message
        SharedDefaults.store.set(raw, forKey: errorsKey)
    }

    static var lastRefresh: Date? {
        get { SharedDefaults.store.object(forKey: lastRefreshKey) as? Date }
        set { SharedDefaults.store.set(newValue, forKey: lastRefreshKey) }
    }

    static func clearAll() {
        SharedDefaults.store.removeObject(forKey: usagesKey)
        SharedDefaults.store.removeObject(forKey: errorsKey)
        SharedDefaults.store.removeObject(forKey: lastRefreshKey)
    }
}

/// Ajustes del ESP32, también en el App Group para que el widget pueda enviar.
enum DeviceSettings {
    private static let enabledKey = "device.enabled"
    private static let hostKey = "device.host"
    private static let lastPushKey = "device.lastPush"
    private static let lastErrorKey = "device.lastError"

    static var isEnabled: Bool {
        get { SharedDefaults.store.bool(forKey: enabledKey) }
        set { SharedDefaults.store.set(newValue, forKey: enabledKey) }
    }

    static var host: String {
        get { SharedDefaults.store.string(forKey: hostKey) ?? "limits.local" }
        set { SharedDefaults.store.set(newValue, forKey: hostKey) }
    }

    static var lastPushAt: Date? {
        get { SharedDefaults.store.object(forKey: lastPushKey) as? Date }
        set { SharedDefaults.store.set(newValue, forKey: lastPushKey) }
    }

    static var lastPushError: String? {
        get { SharedDefaults.store.string(forKey: lastErrorKey) }
        set { SharedDefaults.store.set(newValue, forKey: lastErrorKey) }
    }
}
