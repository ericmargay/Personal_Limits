import Foundation

struct AccountInfo: Sendable {
    var label: String?
    var plan: String?
}

/// Un origen de límites de uso.
protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    var oauth: OAuthConfig { get }

    /// Lee el uso con un token ya válido y lo convierte al modelo común.
    func fetchUsage(token: String, credential: Credential) async throws -> ProviderUsage

    /// Datos de cuenta opcionales tras iniciar sesión (etiqueta, plan).
    func accountInfo(token: String) async -> AccountInfo?
}

extension UsageProvider {
    func accountInfo(token: String) async -> AccountInfo? { nil }

    /// Flujo común: token válido → lectura → si 401, una renovación y reintento.
    func fetchUsage(allowTokenRefresh: Bool) async throws -> ProviderUsage {
        let client = OAuthClient.shared
        let token = try await client.validAccessToken(provider: id, config: oauth,
                                                      allowRefresh: allowTokenRefresh)
        guard let credential = CredentialStore.load(id) else { throw ProviderError.notConnected }
        do {
            return try await fetchUsage(token: token, credential: credential)
        } catch ProviderError.unauthorized {
            // Válido según nuestro reloj pero rechazado: una renovación forzada
            // cubre desfase horario y revocaciones del servidor.
            guard allowTokenRefresh, credential.canRefresh else {
                throw credential.source == .manual ? ProviderError.manualTokenExpired : ProviderError.sessionExpired
            }
            let renewed = try await client.refresh(provider: id, config: oauth, replacing: token)
            do {
                return try await fetchUsage(token: renewed.accessToken, credential: renewed)
            } catch ProviderError.unauthorized {
                throw ProviderError.sessionExpired
            }
        }
    }
}

enum ProviderRegistry {
    static let all: [any UsageProvider] = [ClaudeProvider(), CodexProvider()]

    static func provider(for id: ProviderID) -> any UsageProvider {
        all.first { $0.id == id }!
    }
}
