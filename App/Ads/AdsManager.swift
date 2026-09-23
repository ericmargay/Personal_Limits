import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import Observation
import UserMessagingPlatform

/// Consentimiento (UMP), permiso de seguimiento (ATT) e inicialización del SDK.
///
/// Orden recomendado por Google: consentimiento → ATT → `MobileAds.start()` →
/// pedir anuncios. Todo es tolerante a fallos: si algo falla, simplemente no se
/// muestran anuncios.
@MainActor
@Observable
final class AdsManager {
    private(set) var isReady = false
    private(set) var isPrivacyOptionsRequired = false
    private var hasStarted = false

    func prepare() async {
        guard AdsConfig.isEnabled, !hasStarted else { return }
        hasStarted = true

        await gatherConsent()
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else { return }

        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        await MobileAds.shared.start()
        isReady = true
    }

    /// Pide la información de consentimiento en cada arranque y muestra el
    /// formulario si hace falta (usuarios del EEE/UK con mensaje configurado).
    private func gatherConsent() async {
        let parameters = RequestParameters()
        let updateError: Error? = await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                continuation.resume(returning: error)
            }
        }
        guard updateError == nil else { return }
        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // Sin formulario (fuera del EEE, o AdMob sin mensaje configurado): se sigue.
        }
    }

    /// Reabre las opciones de privacidad (obligatorio ofrecerlo en el EEE/UK).
    func presentPrivacyOptions() async {
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
}
