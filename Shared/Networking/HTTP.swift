import Foundation

/// Utilidades HTTP/JSON compartidas por los proveedores.
enum HTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = [
            "User-Agent": AppConfig.userAgent,
            "Accept": "application/json",
        ]
        return URLSession(configuration: config)
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Ejecuta la petición y devuelve datos + respuesta HTTP, mapeando los fallos
    /// de transporte a `ProviderError.network`.
    static func data(for request: URLRequest,
                     session: URLSession = HTTP.session) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.badResponse("respuesta no HTTP")
        }
        return (data, http)
    }

    /// Espera un 2xx con cuerpo JSON; mapea 401/403/429 a errores propios.
    static func json(_ request: URLRequest) async throws -> Data {
        let (data, http) = try await data(for: request)
        switch http.statusCode {
        case 200...299:
            return data
        case 401, 403:
            throw ProviderError.unauthorized
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw ProviderError.rateLimited(retryAfter: retry)
        default:
            let body = String(decoding: data.prefix(160), as: UTF8.self)
            throw ProviderError.badResponse("HTTP \(http.statusCode) \(body)")
        }
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()

    static func date(iso string: String?) -> Date? {
        guard let string else { return nil }
        return isoFractional.date(from: string) ?? iso.date(from: string)
    }

    static func date(epochSeconds: Double?) -> Date? {
        guard let epochSeconds, epochSeconds > 0 else { return nil }
        return Date(timeIntervalSince1970: epochSeconds)
    }
}

/// Número que puede llegar como entero, decimal o cadena numérica.
struct LooseDouble: Decodable, Sendable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = Double(string)
        } else {
            value = nil
        }
    }
}
