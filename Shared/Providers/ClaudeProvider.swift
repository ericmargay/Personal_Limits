import Foundation

/// Claude (suscripción Pro/Max) a través del mismo OAuth que usa Claude Code.
///
/// Endpoints no documentados; pueden cambiar sin aviso.
struct ClaudeProvider: UsageProvider {
    let id: ProviderID = .claude

    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let profileURL = URL(string: "https://api.anthropic.com/api/oauth/profile")!
    static let oauthBeta = "oauth-2025-04-20"

    let oauth = OAuthConfig(
        clientID: "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
        authorizeURL: "https://claude.com/cai/oauth/authorize",
        tokenURL: "https://platform.claude.com/v1/oauth/token",
        // Petición mínima de solo lectura. `org:create_api_key` hay que pedirlo
        // (si no, authorize devuelve "Invalid request format") pero el servidor
        // NO lo concede: el token queda con `user:profile`, que puede leer el
        // uso pero no enviar prompts ni gastar cuota.
        scopes: "org:create_api_key user:profile",
        fixedPort: nil,
        callbackPath: "/callback",
        extraAuthorizeParams: ["code": "true"],
        exchangeHeaders: ["anthropic-beta": Self.oauthBeta]
    )

    private struct Payload: Decodable {
        struct Window: Decodable {
            var utilization: LooseDouble?
            var percent: LooseDouble?
            var resetsAt: String?
            var value: Double? { utilization?.value ?? percent?.value }
        }
        var fiveHour: Window?
        var sevenDay: Window?
        var sevenDayOpus: Window?
        var sevenDaySonnet: Window?
    }

    private struct Profile: Decodable {
        struct Account: Decodable {
            var emailAddress: String?
            var hasClaudeMax: Bool?
            var hasClaudePro: Bool?
        }
        var account: Account?
    }

    private func authorized(_ url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.oauthBeta, forHTTPHeaderField: "anthropic-beta")
        return request
    }

    func fetchUsage(token: String, credential: Credential) async throws -> ProviderUsage {
        let data = try await HTTP.json(authorized(Self.usageURL, token: token))
        let payload: Payload
        do {
            payload = try HTTP.decoder.decode(Payload.self, from: data)
        } catch {
            throw ProviderError.badResponse("JSON de Claude no reconocido")
        }

        var windows: [UsageWindow] = []
        if let window = payload.fiveHour, let percent = window.value {
            windows.append(UsageWindow(id: "five_hour", label: "Sesión", detail: "ventana de 5 h",
                                       percent: percent, resetsAt: HTTP.date(iso: window.resetsAt)))
        }
        if let window = payload.sevenDay, let percent = window.value {
            windows.append(UsageWindow(id: "seven_day", label: "Semana", detail: "7 días, todos los modelos",
                                       percent: percent, resetsAt: HTTP.date(iso: window.resetsAt)))
        }
        // Las ventanas semanales por modelo suelen venir a null; se añade la que exista.
        if let window = payload.sevenDayOpus, let percent = window.value {
            windows.append(UsageWindow(id: "seven_day_opus", label: "Semana · Opus", detail: "7 días",
                                       percent: percent, resetsAt: HTTP.date(iso: window.resetsAt)))
        } else if let window = payload.sevenDaySonnet, let percent = window.value {
            windows.append(UsageWindow(id: "seven_day_sonnet", label: "Semana · Sonnet", detail: "7 días",
                                       percent: percent, resetsAt: HTTP.date(iso: window.resetsAt)))
        }
        guard !windows.isEmpty else { throw ProviderError.badResponse("sin ventanas de uso") }

        return ProviderUsage(provider: id, account: credential.accountLabel, plan: credential.plan,
                             windows: windows, fetchedAt: Date())
    }

    func accountInfo(token: String) async -> AccountInfo? {
        guard let data = try? await HTTP.json(authorized(Self.profileURL, token: token)),
              let profile = try? HTTP.decoder.decode(Profile.self, from: data),
              let account = profile.account else { return nil }
        let plan: String?
        if account.hasClaudeMax == true {
            plan = "Max"
        } else if account.hasClaudePro == true {
            plan = "Pro"
        } else {
            plan = nil
        }
        return AccountInfo(label: account.emailAddress, plan: plan)
    }
}
