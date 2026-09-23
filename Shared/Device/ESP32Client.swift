import Foundation

/// Lo que recibe el ESP32 en `POST /usage`.
struct DevicePayload: Codable, Sendable {
    struct Window: Codable, Sendable {
        var id: String
        var label: String
        var percent: Double
        var resetsAt: Int?
    }
    struct Provider: Codable, Sendable {
        var id: String
        var name: String
        var account: String?
        var windows: [Window]
    }

    var updatedAt: Int
    var providers: [Provider]

    init(usages: [ProviderID: ProviderUsage], now: Date = Date()) {
        updatedAt = Int(now.timeIntervalSince1970)
        providers = ProviderID.allCases.compactMap { id in
            guard let usage = usages[id] else { return nil }
            return Provider(
                id: id.rawValue,
                name: id.displayName,
                account: usage.account,
                windows: usage.windows.map {
                    Window(id: $0.id, label: $0.label, percent: $0.clampedPercent,
                           resetsAt: $0.resetsAt.map { Int($0.timeIntervalSince1970) })
                }
            )
        }
    }
}

enum DeviceError: LocalizedError {
    case invalidHost
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidHost: return "Dirección del ESP32 no válida."
        case .http(let code): return "El ESP32 respondió HTTP \(code)."
        }
    }
}

/// Cliente HTTP hacia el firmware del ESP32 en la red local.
enum ESP32Client {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Acepta "limits.local", "192.168.1.50", "192.168.1.50:8080" o una URL completa.
    static func endpoint(host: String, path: String) -> URL? {
        var text = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard var components = URLComponents(string: text), components.host?.isEmpty == false else { return nil }
        components.path = path
        components.query = nil
        return components.url
    }

    static func push(_ usages: [ProviderID: ProviderUsage], host: String) async throws {
        guard let url = endpoint(host: host, path: "/usage") else { throw DeviceError.invalidHost }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DevicePayload(usages: usages))
        let (_, http) = try await HTTP.data(for: request, session: session)
        guard (200...299).contains(http.statusCode) else { throw DeviceError.http(http.statusCode) }
    }

    /// `GET /` del firmware: devuelve el texto de estado que responde el ESP32.
    static func status(host: String) async throws -> String {
        guard let url = endpoint(host: host, path: "/") else { throw DeviceError.invalidHost }
        let (data, http) = try await HTTP.data(for: URLRequest(url: url), session: session)
        guard (200...299).contains(http.statusCode) else { throw DeviceError.http(http.statusCode) }
        return String(decoding: data.prefix(400), as: UTF8.self)
    }
}
