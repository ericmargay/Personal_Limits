import Foundation

/// Convierte texto pegado (ficheros de credenciales del Mac o un token suelto)
/// en una credencial `manual`, que nunca se renueva desde el iPhone.
enum CredentialImporter {
    struct Imported {
        let provider: ProviderID
        let credential: Credential
    }

    enum Failure: LocalizedError {
        case unrecognized
        var errorDescription: String? {
            "No se reconoce el formato. Pega el contenido de ~/.claude/.credentials.json, "
            + "~/.codex/auth.json o un token de acceso."
        }
    }

    static func parse(_ text: String) throws -> Imported {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            // ~/.claude/.credentials.json
            if let claude = object["claudeAiOauth"] as? [String: Any],
               let token = claude["accessToken"] as? String {
                let expires = (claude["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
                let plan = (claude["subscriptionType"] as? String).map { $0.prefix(1).uppercased() + $0.dropFirst() }
                return Imported(provider: .claude, credential: Credential(
                    accessToken: token, expiresAt: expires, plan: plan, source: .manual))
            }

            // ~/.codex/auth.json
            if let tokens = object["tokens"] as? [String: Any],
               let access = tokens["access_token"] as? String {
                return Imported(provider: .codex, credential: codexCredential(
                    access: access, idToken: tokens["id_token"] as? String,
                    accountID: tokens["account_id"] as? String))
            }

            // Objeto genérico con access_token / accessToken
            if let token = (object["access_token"] ?? object["accessToken"]) as? String {
                return try parse(token)
            }
        }

        if trimmed.hasPrefix("sk-ant-") {
            return Imported(provider: .claude, credential: Credential(accessToken: trimmed, source: .manual))
        }
        if trimmed.hasPrefix("eyJ"), JWT.chatGPTAccountID(in: JWT.claims(trimmed)) != nil {
            return Imported(provider: .codex, credential: codexCredential(access: trimmed, idToken: nil, accountID: nil))
        }
        throw Failure.unrecognized
    }

    private static func codexCredential(access: String, idToken: String?, accountID: String?) -> Credential {
        let accessClaims = JWT.claims(access)
        let idClaims = JWT.claims(idToken)
        return Credential(
            accessToken: access,
            expiresAt: JWT.expiry(in: accessClaims),
            accountLabel: JWT.email(in: idClaims) ?? JWT.email(in: accessClaims),
            accountID: accountID ?? JWT.chatGPTAccountID(in: idClaims) ?? JWT.chatGPTAccountID(in: accessClaims),
            source: .manual
        )
    }
}
