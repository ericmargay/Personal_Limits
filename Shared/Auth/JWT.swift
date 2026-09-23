import Foundation

/// Lectura de claims de un JWT SIN verificar la firma. Solo se usa para
/// etiquetas (email) y el id de cuenta de ChatGPT; la API es quien manda.
enum JWT {
    static func claims(_ token: String?) -> [String: Any]? {
        guard let token else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj
    }

    /// OpenAI anida el id de cuenta bajo un claim con namespace (`…/auth`).
    static func chatGPTAccountID(in claims: [String: Any]?) -> String? {
        guard let claims else { return nil }
        for (key, value) in claims where key.hasSuffix("/auth") {
            if let auth = value as? [String: Any],
               let id = auth["chatgpt_account_id"] as? String {
                return id
            }
        }
        return claims["chatgpt_account_id"] as? String
    }

    static func email(in claims: [String: Any]?) -> String? {
        guard let claims else { return nil }
        if let email = claims["email"] as? String { return email }
        for (key, value) in claims where key.hasSuffix("/profile") {
            if let profile = value as? [String: Any], let email = profile["email"] as? String {
                return email
            }
        }
        return nil
    }

    static func expiry(in claims: [String: Any]?) -> Date? {
        guard let exp = claims?["exp"] as? Double, exp > 0 else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}
