import BackgroundTasks
import Foundation

/// Actualización periódica en segundo plano con `BGAppRefreshTask`.
///
/// iOS decide cuándo ejecutarla (normalmente cada 15–60 min si la app se usa
/// con regularidad). Cada ejecución renueva tokens si hace falta, guarda la
/// lectura, recarga el widget y envía al ESP32.
enum BackgroundRefresh {
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppConfig.backgroundRefreshTaskID,
                                        using: nil) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task)
        }
    }

    static func schedule(after interval: TimeInterval = 15 * 60) {
        let request = BGAppRefreshTaskRequest(identifier: AppConfig.backgroundRefreshTaskID)
        request.earliestBeginDate = Date().addingTimeInterval(interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Sin permiso de "Actualización en segundo plano" o en simulador: no pasa nada.
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()   // encadena la siguiente ejecución
        let work = Task {
            await UsageRefresher.refreshAll(allowTokenRefresh: true)
            WatchBridge.shared.sendCurrentSnapshot()
            if !Task.isCancelled {
                task.setTaskCompleted(success: true)
            }
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
