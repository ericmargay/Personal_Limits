import Foundation

/// Identificadores compartidos por la app y el widget.
/// Deben coincidir con `project.yml` y con ambos ficheros `.entitlements`.
enum AppConfig {
    static let bundleID = "com.ericmargay.personallimits"

    /// App Group: comparte la caché de uso (UserDefaults) entre app y widget.
    static let appGroup = "group.com.ericmargay.personallimits"

    /// Un App Group también sirve como grupo de acceso al llavero sin prefijo de
    /// Team ID, así que app y widget comparten tokens solo con el entitlement de
    /// App Groups (no hace falta "Keychain Sharing").
    static let keychainAccessGroup = appGroup
    static let keychainService = "PersonalLimits"

    static let backgroundRefreshTaskID = "com.ericmargay.personallimits.refresh"

    /// Varios hosts de tokens están detrás de Cloudflare y responden 403 a
    /// clientes sin User-Agent reconocible.
    static let userAgent = "PersonalLimits/1.0 (iOS; monitor personal de uso)"

    /// Servicio Bonjour que anuncia el firmware del ESP32.
    static let deviceServiceType = "_limits._tcp"

    static let widgetKind = "PersonalLimitsWidget"
}
