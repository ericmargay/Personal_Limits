import Foundation

/// Proveedores que la app sabe leer.
enum ProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    var vendorName: String {
        switch self {
        case .claude: return "Anthropic"
        case .codex: return "OpenAI"
        }
    }

    var symbolName: String {
        switch self {
        case .claude: return "sparkles"
        case .codex: return "terminal"
        }
    }
}

/// Una ventana de límite ("sesión", "semana", …) de un proveedor.
struct UsageWindow: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var label: String
    var detail: String?
    /// Porcentaje ya consumido de la ventana, 0–100.
    var percent: Double
    var resetsAt: Date?

    var clampedPercent: Double { min(max(percent, 0), 100) }
    var fraction: Double { clampedPercent / 100 }
}

/// Lectura completa de un proveedor.
struct ProviderUsage: Codable, Hashable, Identifiable, Sendable {
    var provider: ProviderID
    var account: String?
    var plan: String?
    var windows: [UsageWindow]
    var fetchedAt: Date

    var id: ProviderID { provider }
    var primary: UsageWindow? { windows.first }
    var secondary: UsageWindow? { windows.count > 1 ? windows[1] : nil }
    var highest: UsageWindow? { windows.max { $0.clampedPercent < $1.clampedPercent } }
}

enum ProviderError: LocalizedError, Sendable {
    case notConnected
    case sessionExpired
    case manualTokenExpired
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case network(String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Proveedor no conectado."
        case .sessionExpired:
            return "La sesión caducó. Vuelve a conectar el proveedor."
        case .manualTokenExpired:
            return "El token pegado caducó. Pega uno nuevo o inicia sesión."
        case .unauthorized:
            return "El proveedor rechazó las credenciales."
        case .rateLimited(let retry):
            if let retry, retry > 0 {
                return "Demasiadas consultas. Reintenta en \(Int(retry.rounded(.up))) s."
            }
            return "Demasiadas consultas. Reintenta en unos minutos."
        case .network(let detail):
            return "Sin conexión: \(detail)"
        case .badResponse(let detail):
            return "Respuesta inesperada: \(detail)"
        }
    }
}
