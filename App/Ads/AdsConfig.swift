import Foundation

/// Identificadores de AdMob.
///
/// Los de prueba son los oficiales de Google y funcionan sin cuenta, pero NUNCA
/// se publica con ellos (AdMob suspende la cuenta por tráfico inválido). Pasos:
///   1. AdMob → Apps → Añadir app → copia el "ID de aplicación" a
///      GADApplicationIdentifier en App/Info.plist.
///   2. AdMob → Bloques de anuncios → Banner → copia el ID aquí abajo.
///   3. AdMob → Privacidad y mensajes → crea el mensaje GDPR (EEE/UK) y el de
///      IDFA; la app lo muestra sola con el SDK UMP.
enum AdsConfig {
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let productionBannerUnitID = "REEMPLAZA-CON-TU-ID-DE-BLOQUE"

    #if DEBUG
    static let bannerUnitID = testBannerUnitID
    static let isEnabled = true
    #else
    static let bannerUnitID = productionBannerUnitID
    /// En Release solo se piden anuncios si hay un ID real configurado.
    static let isEnabled = !productionBannerUnitID.hasPrefix("REEMPLAZA")
    #endif
}
