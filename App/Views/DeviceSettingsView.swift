import SwiftUI

struct DeviceSettingsView: View {
    @Environment(UsageStore.self) private var store
    @State private var enabled = DeviceSettings.isEnabled
    @State private var host = DeviceSettings.host
    @State private var discovery = DeviceDiscovery()
    @State private var status: String?
    @State private var isWorking = false
    @State private var lastPushAt = DeviceSettings.lastPushAt
    @State private var lastPushError = DeviceSettings.lastPushError

    var body: some View {
        Form {
            Section {
                Toggle("Enviar uso al ESP32", isOn: $enabled)
                TextField("limits.local o 192.168.1.50", text: $host)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Dispositivo")
            } footer: {
                Text("Cada vez que la app o el widget actualizan los datos se envían por HTTP (POST /usage) al ESP32 en tu red Wi‑Fi.")
            }

            Section {
                if discovery.devices.isEmpty {
                    HStack(spacing: 8) {
                        if discovery.isBrowsing { ProgressView() }
                        Text(discovery.isBrowsing ? "Buscando dispositivos…" : "Ningún dispositivo encontrado")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(discovery.devices) { device in
                    Button {
                        host = device.host
                    } label: {
                        HStack {
                            Label(device.name, systemImage: "cpu")
                            Spacer()
                            Text(device.host)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Encontrados en la red (Bonjour)")
            }

            Section {
                Button {
                    test()
                } label: {
                    Label("Probar conexión", systemImage: "antenna.radiowaves.left.and.right")
                }
                Button {
                    pushNow()
                } label: {
                    Label("Enviar datos ahora", systemImage: "paperplane")
                }
                .disabled(store.cards.isEmpty)
                if isWorking { ProgressView() }
                if let status {
                    Text(status).font(.footnote)
                }
                if let lastPushAt {
                    LabeledContent("Último envío") {
                        Text(lastPushAt, style: .relative) + Text(" atrás")
                    }
                }
                if let lastPushError {
                    Text(lastPushError)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Prueba")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("¿Prefieres uno ya montado?")
                        .font(.headline)
                    Text("ESP32 + anillo de 16 NeoPixels + carcasa, con el firmware cargado. Lo enchufas, le das tu Wi‑Fi y aparece aquí arriba automáticamente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Link(destination: StoreLinks.etsyShop) {
                    Label("Ver el módulo en Etsy", systemImage: "bag")
                }
                Link(destination: StoreLinks.firmware) {
                    Label("Montarlo tú mismo (firmware en GitHub)", systemImage: "wrench.and.screwdriver")
                }
            } header: {
                Text("Módulo listo para usar")
            }
        }
        .navigationTitle("ESP32")
        .onChange(of: enabled) { _, value in DeviceSettings.isEnabled = value }
        .onChange(of: host) { _, value in DeviceSettings.host = value }
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
    }

    private func test() {
        run {
            let reply = try await ESP32Client.status(host: host)
            return "Respuesta del ESP32: \(reply)"
        }
    }

    private func pushNow() {
        run {
            try await ESP32Client.push(UsageCache.loadAll(), host: host)
            DeviceSettings.lastPushAt = Date()
            DeviceSettings.lastPushError = nil
            return "Datos enviados correctamente."
        }
    }

    private func run(_ work: @escaping () async throws -> String) {
        isWorking = true
        status = nil
        Task {
            defer {
                isWorking = false
                lastPushAt = DeviceSettings.lastPushAt
                lastPushError = DeviceSettings.lastPushError
            }
            do {
                status = try await work()
            } catch {
                status = "Error: \(error.localizedDescription)"
            }
        }
    }
}
