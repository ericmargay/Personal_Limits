import Foundation

/// Codex / ChatGPT. Mismo flujo loopback que Claude con una diferencia:
/// OpenAI registró un redirect exacto para el cliente de Codex, así que el
/// listener debe usar el puerto 1455.
///
/// El endpoint de uso es el que consulta Codex CLI; no está documentado.
struct CodexProvider: UsageProvider {
    let id: ProviderID = .codex

    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    let oauth = OAuthConfig(
        clientID: "app_EMoamEEZ73f0CkXaXp7hrann",
        authorizeURL: "https://auth.openai.com/oauth/authorize",
        tokenURL: "https://auth.openai.com/oauth/token",
        scopes: "openid profile email offline_access api.connectors.read api.connectors.invoke",
        fixedPort: 1455,
        callbackPath: "/auth/callback",
        extraAuthorizeParams: [:],
        exchangeHeaders: [:]
    )

    private struct Payload: Decodable {
        struct Window: Decodable {
            var usedPercent: LooseDouble?
            var limitWindowSeconds: LooseDouble?
            var resetAfterSeconds: LooseDouble?
            var resetAt: LooseDouble?
        }
        struct RateLimit: Decodable {
            var primaryWindow: Window?
            var secondaryWindow: Window?
        }
        var planType: String?
        var rateLimit: RateLimit?
    }

    func fetchUsage(token: String, credential: Credential) async throws -> ProviderUsage {
        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let accountID = credential.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let data = try await HTTP.json(request)
        let payload: Payload
        do {
            payload = try HTTP.decoder.decode(Payload.self, from: data)
        } catch {
            throw ProviderError.badResponse("JSON de Codex no reconocido")
        }

        var windows: [UsageWindow] = []
        if let window = Self.window(payload.rateLimit?.primaryWindow, id: "primary") {
            windows.append(window)
        }
        if let window = Self.window(payload.rateLimit?.secondaryWindow, id: "secondary") {
            windows.append(window)
        }
        guard !windows.isEmpty else { throw ProviderError.badResponse("sin ventanas de uso") }

        let plan = payload.planType.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? credential.plan
        return ProviderUsage(provider: id, account: credential.accountLabel, plan: plan,
                             windows: windows, fetchedAt: Date())
    }

    /// La respuesta nombra la duración de la ventana, no su nombre.
    private static func window(_ raw: Payload.Window?, id: String) -> UsageWindow? {
        guard let raw, let percent = raw.usedPercent?.value else { return nil }
        let seconds = raw.limitWindowSeconds?.value ?? 0
        // `reset_at` es epoch; si falta, la respuesta trae `reset_after_seconds`.
        var resetsAt = HTTP.date(epochSeconds: raw.resetAt?.value)
        if resetsAt == nil, let after = raw.resetAfterSeconds?.value, after > 0 {
            resetsAt = Date().addingTimeInterval(after)
        }
        let (label, detail) = describe(seconds: seconds)
        return UsageWindow(id: id, label: label, detail: detail, percent: percent, resetsAt: resetsAt)
    }

    private static func describe(seconds: Double) -> (String, String?) {
        switch seconds {
        case 0: return ("Uso", nil)
        case ..<86_400: return ("Sesión", "ventana de \(Int(seconds / 3600)) h")
        case ..<2_592_000: return ("Semana", "\(Int(seconds / 86_400)) días")
        default: return ("Mes", "\(Int(seconds / 86_400)) días")
        }
    }
}
