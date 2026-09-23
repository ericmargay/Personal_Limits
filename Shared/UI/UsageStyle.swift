import SwiftUI

/// Colores y formatos comunes a la app y al widget.
enum UsageStyle {
    static func color(forPercent percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case ..<75: return .yellow
        case ..<90: return .orange
        default: return .red
        }
    }

    static func tint(_ provider: ProviderID) -> Color {
        switch provider {
        case .claude: return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex: return Color(red: 0.06, green: 0.64, blue: 0.50)
        }
    }

    static func percentText(_ percent: Double) -> String {
        "\(Int(min(max(percent, 0), 100).rounded()))%"
    }
}

/// Datos de muestra para el placeholder del widget y las previews.
enum DemoData {
    static let usages: [ProviderUsage] = [
        ProviderUsage(
            provider: .claude, account: "tu@correo.com", plan: "Max",
            windows: [
                UsageWindow(id: "five_hour", label: "Sesión", detail: "ventana de 5 h",
                            percent: 42, resetsAt: Date().addingTimeInterval(2 * 3600 + 13 * 60)),
                UsageWindow(id: "seven_day", label: "Semana", detail: "7 días, todos los modelos",
                            percent: 18, resetsAt: Date().addingTimeInterval(3 * 86_400)),
            ],
            fetchedAt: Date()
        ),
        ProviderUsage(
            provider: .codex, account: "tu@correo.com", plan: "Plus",
            windows: [
                UsageWindow(id: "primary", label: "Sesión", detail: "ventana de 5 h",
                            percent: 7, resetsAt: Date().addingTimeInterval(4 * 3600)),
                UsageWindow(id: "secondary", label: "Semana", detail: "7 días",
                            percent: 63, resetsAt: Date().addingTimeInterval(5 * 86_400)),
            ],
            fetchedAt: Date()
        ),
    ]
}
