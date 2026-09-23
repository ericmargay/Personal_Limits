import CryptoKit
import Foundation

/// Parámetros OAuth (cliente público + PKCE) de un proveedor.
struct OAuthConfig: Sendable {
    var clientID: String
    var authorizeURL: String
    var tokenURL: String
    var scopes: String
    /// Puerto fijo cuando el proveedor registró un redirect exacto (Codex: 1455).
    var fixedPort: UInt16?
    var callbackPath: String
    var extraAuthorizeParams: [String: String]
    var exchangeHeaders: [String: String]
}

/// Un intento de autorización en curso.
struct AuthorizationRequest: Sendable {
    let url: URL
    let verifier: String
    let state: String
    let redirectURI: String
}

/// Login PKCE + renovación silenciosa, común a todos los proveedores OAuth.
///
/// La renovación puede lanzarse desde la app o desde el widget (procesos
/// distintos). Como los refresh tokens rotan en cada uso, dos renovaciones
/// simultáneas dejarían una sesión muerta; por eso se serializan con un
/// bloqueo de fichero en el contenedor del App Group.
actor OAuthClient {
    static let shared = OAuthClient()

    // MARK: PKCE

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func randomString(bytes: Int = 32) -> String {
        var data = Data(count: bytes)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
        return base64URL(data)
    }

    /// Construye la URL de autorización para un puerto loopback ya abierto.
    /// `state` y el verifier son de 32 bytes: Claude rechaza estados más cortos.
    func beginAuthorization(config: OAuthConfig, port: UInt16) -> AuthorizationRequest {
        let verifier = randomString()
        let state = randomString()
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let redirectURI = "http://localhost:\(port)\(config.callbackPath)"

        var components = URLComponents(string: config.authorizeURL)!
        var items = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: config.scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        for (name, value) in config.extraAuthorizeParams.sorted(by: { $0.key < $1.key }) {
            items.append(URLQueryItem(name: name, value: value))
        }
        components.queryItems = items

        return AuthorizationRequest(url: components.url!, verifier: verifier,
                                    state: state, redirectURI: redirectURI)
    }

    // MARK: Intercambio y renovación

    /// Cambia el código por tokens y los guarda.
    @discardableResult
    func exchange(code: String, state: String, request: AuthorizationRequest,
                  config: OAuthConfig, provider: ProviderID) async throws -> Credential {
        let credential = try await postToken([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": request.redirectURI,
            "client_id": config.clientID,
            "code_verifier": request.verifier,
            "state": state,
        ], config: config, headers: config.exchangeHeaders, existing: nil)
        CredentialStore.save(credential, for: provider)
        return credential
    }

    /// Devuelve un access token válido, renovándolo antes si caducó.
    func validAccessToken(provider: ProviderID, config: OAuthConfig,
                          allowRefresh: Bool) async throws -> String {
        guard let credential = CredentialStore.load(provider) else { throw ProviderError.notConnected }
        guard credential.isExpired else { return credential.accessToken }
        if credential.source == .manual { throw ProviderError.manualTokenExpired }
        guard allowRefresh, credential.canRefresh else { throw ProviderError.sessionExpired }
        return try await refresh(provider: provider, config: config, replacing: credential.accessToken).accessToken
    }

    /// Renueva el par de tokens y persiste el refresh token rotado.
    ///
    /// `staleToken` es el access token que el llamante considera inservible. Si al
    /// obtener el bloqueo el llavero ya contiene otro distinto, es que el otro
    /// proceso acaba de renovar y se devuelve ese sin tocar nada.
    @discardableResult
    func refresh(provider: ProviderID, config: OAuthConfig, replacing staleToken: String) async throws -> Credential {
        try await withCrossProcessLock {
            guard let existing = CredentialStore.load(provider) else { throw ProviderError.notConnected }
            if existing.accessToken != staleToken { return existing }
            if existing.source == .manual { throw ProviderError.manualTokenExpired }
            guard existing.canRefresh, let refreshToken = existing.refreshToken else {
                throw ProviderError.sessionExpired
            }
            var body: [String: Any] = [
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
                "client_id": config.clientID,
            ]
            // Se repite el scope CONCEDIDO (no el solicitado): Claude pide
            // org:create_api_key pero no lo concede, y repetirlo da invalid_scope.
            if let scope = existing.scope, !scope.isEmpty {
                body["scope"] = scope
            }
            do {
                let renewed = try await postToken(body, config: config, headers: [:], existing: existing)
                CredentialStore.save(renewed, for: provider)
                return renewed
            } catch ProviderError.unauthorized {
                // Con el bloqueo en mano nadie más ha podido rotar el token: la
                // cadena está realmente muerta (caducada o revocada).
                CredentialStore.clear(provider)
                throw ProviderError.sessionExpired
            }
        }
    }

    // MARK: Bloqueo entre procesos

    private static let lockURL: URL = {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroup)
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("oauth-refresh.lock")
    }()

    /// Serializa `body` entre la app y el widget con `flock`. Espera hasta ~10 s
    /// a que el otro proceso termine; si no se puede abrir el fichero, sigue sin
    /// bloqueo (mejor una renovación arriesgada que ninguna).
    private func withCrossProcessLock<T>(_ body: () async throws -> T) async throws -> T {
        let fd = open(Self.lockURL.path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { return try await body() }
        defer { close(fd) }   // cerrar el descriptor libera el bloqueo

        var attempts = 0
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            attempts += 1
            if attempts > 100 { throw ProviderError.network("otra renovación de sesión en curso") }
            try await Task.sleep(for: .milliseconds(100))
        }
        return try await body()
    }

    // MARK: Red

    private func postToken(_ body: [String: Any], config: OAuthConfig,
                           headers: [String: String], existing: Credential?) async throws -> Credential {
        var request = URLRequest(url: URL(string: config.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, http) = try await HTTP.data(for: request)
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard (200...299).contains(http.statusCode), let obj,
              let access = obj["access_token"] as? String else {
            let code = obj?["error"] as? String
            if http.statusCode == 401 || ["invalid_grant", "invalid_request", "invalid_scope"].contains(code ?? "") {
                throw ProviderError.unauthorized
            }
            let detail = (obj?["error_description"] as? String) ?? code
                ?? String(decoding: data.prefix(200), as: UTF8.self)
            throw ProviderError.badResponse("token (HTTP \(http.statusCode)): \(detail)")
        }

        var credential = Credential(
            accessToken: access,
            // El refresh token rota en cada uso: si no viene uno nuevo, se
            // conserva el usado.
            refreshToken: (obj["refresh_token"] as? String) ?? (body["refresh_token"] as? String),
            expiresAt: (obj["expires_in"] as? Double).map { Date().addingTimeInterval($0) },
            scope: (obj["scope"] as? String) ?? existing?.scope,
            accountLabel: existing?.accountLabel,
            accountID: existing?.accountID,
            plan: existing?.plan,
            source: .oauth
        )

        // OpenAI: el id_token trae email e id de cuenta de ChatGPT.
        if let claims = JWT.claims(obj["id_token"] as? String) {
            if let email = JWT.email(in: claims) { credential.accountLabel = email }
            if let accountID = JWT.chatGPTAccountID(in: claims) { credential.accountID = accountID }
        }
        // Anthropic: la respuesta puede traer la cuenta.
        if let account = obj["account"] as? [String: Any],
           let email = account["email_address"] as? String {
            credential.accountLabel = email
        }
        return credential
    }
}
