import Foundation
import Security

/// Almacén de credenciales por proveedor, compartido con el widget.
///
/// En dispositivo real usa el llavero con el App Group como grupo de acceso.
/// El simulador no tiene perfil de aprovisionamiento y los grupos de acceso
/// fallan ahí, así que en simulador se guarda en el contenedor del App Group
/// para poder probar app y widget juntos mientras se desarrolla.
enum CredentialStore {

    #if targetEnvironment(simulator)

    private static func key(_ provider: ProviderID) -> String { "credential.\(provider.rawValue)" }

    static func save(_ credential: Credential, for provider: ProviderID) {
        guard let data = try? JSONEncoder().encode(credential) else { return }
        SharedDefaults.store.set(data, forKey: key(provider))
    }

    static func load(_ provider: ProviderID) -> Credential? {
        guard let data = SharedDefaults.store.data(forKey: key(provider)) else { return nil }
        return try? JSONDecoder().decode(Credential.self, from: data)
    }

    static func clear(_ provider: ProviderID) {
        SharedDefaults.store.removeObject(forKey: key(provider))
    }

    #else

    private static func baseQuery(_ provider: ProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: provider.rawValue,
            kSecAttrAccessGroup as String: AppConfig.keychainAccessGroup,
        ]
    }

    static func save(_ credential: Credential, for provider: ProviderID) {
        guard let data = try? JSONEncoder().encode(credential) else { return }
        var query = baseQuery(provider)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        // Legible tras el primer desbloqueo: necesario para la actualización en
        // segundo plano y para el widget con el teléfono bloqueado.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(_ provider: ProviderID) -> Credential? {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Credential.self, from: data)
    }

    static func clear(_ provider: ProviderID) {
        SecItemDelete(baseQuery(provider) as CFDictionary)
    }

    #endif

    static func isConnected(_ provider: ProviderID) -> Bool {
        load(provider) != nil
    }

    static var connectedProviders: [ProviderID] {
        ProviderID.allCases.filter(isConnected)
    }

    static func clearAll() {
        ProviderID.allCases.forEach(clear)
    }
}
