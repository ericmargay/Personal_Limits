import AuthenticationServices
import Foundation
import UIKit

/// Ejecuta el OAuth completo: abre el puerto loopback, muestra Safari, captura
/// el redirect e intercambia el código. `ASWebAuthenticationSession` usa un
/// Safari real fuera de proceso, lo que permite pasar la comprobación anti-bot
/// de Claude (rechaza WKWebView embebidas).
@MainActor
final class ProviderSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {

    enum Failure: LocalizedError {
        case cannotPresent
        case stateMismatch
        case portBusy(UInt16)

        var errorDescription: String? {
            switch self {
            case .cannotPresent:
                return "No se pudo abrir la página de inicio de sesión."
            case .stateMismatch:
                return "La respuesta del proveedor no coincide con la petición. Inténtalo de nuevo."
            case .portBusy(let port):
                return "El puerto \(port) está ocupado y este proveedor lo exige para iniciar sesión."
            }
        }
    }

    private var session: ASWebAuthenticationSession?

    func signIn(_ provider: any UsageProvider) async throws {
        let config = provider.oauth
        let server = LoopbackServer()
        let port: UInt16
        do {
            port = try await server.start(fixedPort: config.fixedPort)
        } catch {
            if let fixed = config.fixedPort { throw Failure.portBusy(fixed) }
            throw error
        }
        defer { server.stop() }

        let request = await OAuthClient.shared.beginAuthorization(config: config, port: port)

        // El esquema propio nunca llega a dispararse: el redirect es
        // http://localhost y lo captura el servidor loopback. Este handler solo
        // sirve para saber que el usuario cerró la hoja.
        let session = ASWebAuthenticationSession(url: request.url, callbackURLScheme: "personallimits") { _, error in
            if let error { server.fail(error) }
        }
        session.presentationContextProvider = self
        // Reutiliza las cookies de Safari: si ya hay sesión, basta con aprobar.
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        guard session.start() else { throw Failure.cannotPresent }
        defer {
            session.cancel()
            self.session = nil
        }

        let callback = try await server.waitForCallback()
        guard callback.state == request.state else { throw Failure.stateMismatch }

        var credential = try await OAuthClient.shared.exchange(code: callback.code, state: callback.state,
                                                               request: request, config: config,
                                                               provider: provider.id)
        if let info = await provider.accountInfo(token: credential.accessToken) {
            credential.accountLabel = info.label ?? credential.accountLabel
            credential.plan = info.plan ?? credential.plan
            CredentialStore.save(credential, for: provider.id)
        }
    }

    /// Cerrar la hoja no merece una alerta.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        return nsError.domain == ASWebAuthenticationSessionErrorDomain
            && nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
    }

    // MARK: ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
