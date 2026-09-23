import Foundation

/// Tokens de un proveedor.
struct Credential: Codable, Sendable {
    enum Source: String, Codable, Sendable {
        /// Obtenido iniciando sesión desde esta app; se puede renovar libremente.
        case oauth
        /// Pegado desde otro equipo. Nunca se renueva, para no rotar la cadena de
        /// refresh tokens que usa ese otro equipo (Claude Code / Codex CLI).
        case manual
    }

    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    /// Scope realmente concedido. Al renovar hay que repetir exactamente este.
    var scope: String?
    var accountLabel: String?
    /// Codex: `ChatGPT-Account-Id` obligatorio en la API de uso.
    var accountID: String?
    var plan: String?
    var source: Source

    init(accessToken: String,
         refreshToken: String? = nil,
         expiresAt: Date? = nil,
         scope: String? = nil,
         accountLabel: String? = nil,
         accountID: String? = nil,
         plan: String? = nil,
         source: Source = .oauth) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.scope = scope
        self.accountLabel = accountLabel
        self.accountID = accountID
        self.plan = plan
        self.source = source
    }

    /// Se considera caducado 5 min antes para no competir con la fecha límite.
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt.addingTimeInterval(-300)
    }

    var canRefresh: Bool {
        source == .oauth && !(refreshToken ?? "").isEmpty
    }
}
