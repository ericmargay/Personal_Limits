import Foundation
import Network

/// Mini servidor HTTP en loopback que captura el redirect de OAuth.
///
/// Ambos proveedores redirigen a `http://localhost:<puerto>/…` (como hacen sus
/// CLIs). `ASWebAuthenticationSession` solo detecta esquemas propios o enlaces
/// universales, así que escuchamos en un puerto local y servimos el redirect.
/// Está ligado a 127.0.0.1: no es alcanzable desde la red y no dispara el
/// permiso de red local. Vive lo que dura un intento de inicio de sesión.
final class LoopbackServer: @unchecked Sendable {

    struct Callback: Sendable {
        let code: String
        let state: String
    }

    enum Failure: LocalizedError {
        case cannotBind
        case providerDeclined(String)

        var errorDescription: String? {
            switch self {
            case .cannotBind:
                return "No se pudo abrir un puerto local para completar el inicio de sesión."
            case .providerDeclined(let detail):
                return "El proveedor rechazó el inicio de sesión: \(detail)"
            }
        }
    }

    private let queue = DispatchQueue(label: "personallimits.loopback")
    private let lock = NSLock()
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var waiter: CheckedContinuation<Callback, Error>?
    private var settledResult: Result<Callback, Error>?
    private var startResumed = false

    private(set) var port: UInt16 = 0

    // MARK: Ciclo de vida

    /// Abre el puerto y lo devuelve. Falla si el listener nunca llega a `.ready`.
    func start(fixedPort: UInt16?) async throws -> UInt16 {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let requested: NWEndpoint.Port = fixedPort.flatMap { NWEndpoint.Port(rawValue: $0) } ?? .any
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: requested)

        let listener: NWListener
        do {
            listener = try NWListener(using: params)
        } catch {
            throw Failure.cannotBind
        }
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }

        let bound: UInt16 = try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                let outcome: Result<UInt16, Error>
                switch state {
                case .ready:
                    outcome = .success(listener.port?.rawValue ?? 0)
                case .failed, .cancelled:
                    outcome = .failure(Failure.cannotBind)
                default:
                    return
                }
                self.lock.lock()
                let alreadyResumed = self.startResumed
                self.startResumed = true
                self.lock.unlock()
                if !alreadyResumed { continuation.resume(with: outcome) }
            }
            listener.start(queue: queue)
        }

        guard bound != 0 else { throw Failure.cannotBind }
        port = bound
        return bound
    }

    func stop() {
        lock.lock()
        let open = connections
        connections = []
        lock.unlock()
        open.forEach { $0.cancel() }
        listener?.cancel()
        listener = nil
    }

    // MARK: Espera

    /// Suspende hasta que el navegador llegue al callback o alguien llame a `fail`.
    func waitForCallback() async throws -> Callback {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let settledResult {
                lock.unlock()
                continuation.resume(with: settledResult)
                return
            }
            waiter = continuation
            lock.unlock()
        }
    }

    /// Desbloquea `waitForCallback` con error (p. ej. el usuario cerró la hoja).
    func fail(_ error: Error) {
        settle(.failure(error))
    }

    private func settle(_ result: Result<Callback, Error>) {
        lock.lock()
        guard settledResult == nil else { lock.unlock(); return }
        settledResult = result
        let continuation = waiter
        waiter = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

    // MARK: HTTP

    private func accept(_ connection: NWConnection) {
        lock.lock()
        connections.append(connection)
        lock.unlock()

        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            guard let self else { return }
            guard let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            self.handle(request: request, on: connection)
        }
    }

    private func handle(request: String, on connection: NWConnection) {
        // Primera línea: GET /callback?code=…&state=… HTTP/1.1
        guard let requestLine = request.split(separator: "\r\n").first else {
            respond(Self.errorPage, on: connection)
            return
        }
        let fields = requestLine.split(separator: " ")
        guard fields.count >= 2,
              let components = URLComponents(string: "http://localhost" + String(fields[1])) else {
            respond(Self.errorPage, on: connection)
            return
        }

        func value(_ name: String) -> String? {
            components.queryItems?.first { $0.name == name }?.value
        }

        if let error = value("error") {
            respond(Self.errorPage, on: connection)
            settle(.failure(Failure.providerDeclined(value("error_description") ?? error)))
            return
        }
        guard let code = value("code"), let state = value("state") else {
            // Favicon u otras peticiones: se ignoran sin cerrar el intento.
            respond(Self.errorPage, on: connection)
            return
        }
        respond(Self.successPage, on: connection)
        settle(.success(Callback(code: code, state: state)))
    }

    private func respond(_ body: String, on connection: NWConnection) {
        let payload = Data(body.utf8)
        let head = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(payload)
        connection.send(content: out, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static let successPage = """
    <!doctype html><meta name=viewport content="width=device-width,initial-scale=1">
    <body style="font:-apple-system-body;padding:3rem;text-align:center">
    <h2>Sesión iniciada</h2><p>Ya puedes volver a Personal Limits.</p></body>
    """

    private static let errorPage = """
    <!doctype html><meta name=viewport content="width=device-width,initial-scale=1">
    <body style="font:-apple-system-body;padding:3rem;text-align:center">
    <h2>No se pudo iniciar sesión</h2><p>Vuelve a la app e inténtalo de nuevo.</p></body>
    """
}
