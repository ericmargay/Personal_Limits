import SwiftUI

struct SettingsView: View {
    @Environment(UsageStore.self) private var store
    @Environment(AdsManager.self) private var ads
    @State private var signIn = ProviderSignIn()
    @State private var busyProvider: ProviderID?
    @State private var errorMessage: String?
    @State private var showImport = false
    @State private var providerToDisconnect: ProviderID?

    var body: some View {
        Form {
            Section {
                ForEach(ProviderID.allCases) { provider in
                    ProviderRow(provider: provider,
                                isBusy: busyProvider == provider,
                                onConnect: { connect(provider) },
                                onDisconnect: { providerToDisconnect = provider })
                }
                Button {
                    showImport = true
                } label: {
                    Label("Pegar credenciales de otro equipo…", systemImage: "doc.on.clipboard")
                }
            } header: {
                Text("Proveedores")
            } footer: {
                Text("Iniciar sesión abre el navegador y guarda un token de solo lectura en el llavero del dispositivo. No se envía a ningún servidor nuestro.")
            }

            Section {
                NavigationLink {
                    DeviceSettingsView()
                } label: {
                    HStack {
                        Label("ESP32 / NeoPixels", systemImage: "cpu")
                        Spacer()
                        Text(DeviceSettings.isEnabled ? DeviceSettings.host : "Desactivado")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Link(destination: StoreLinks.etsyShop) {
                    Label("Módulo ESP32 ya montado (Etsy)", systemImage: "bag")
                }
            } header: {
                Text("Dispositivo físico")
            } footer: {
                Text("Refleja tu uso con LEDs en el escritorio. Puedes montarlo tú con el firmware del repositorio o pedirlo listo para enchufar.")
            }

            Section {
                if let last = store.lastRefresh {
                    LabeledContent("Última lectura") {
                        Text(last, style: .relative) + Text(" atrás")
                    }
                }
                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isRefreshing {
                        HStack { ProgressView(); Text("Actualizando…") }
                    } else {
                        Label("Actualizar ahora", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(store.isRefreshing)
            } header: {
                Text("Actualización")
            } footer: {
                Text("iOS decide cuándo ejecutar la actualización en segundo plano (normalmente cada 15–60 min si usas la app con regularidad). El widget y el Apple Watch se actualizan con cada lectura.")
            }

            Section {
                if ads.isPrivacyOptionsRequired {
                    Button {
                        Task { await ads.presentPrivacyOptions() }
                    } label: {
                        Label("Opciones de privacidad de anuncios", systemImage: "hand.raised")
                    }
                }
                Link(destination: StoreLinks.privacyPolicy) {
                    Label("Política de privacidad", systemImage: "lock.shield")
                }
                Link(destination: StoreLinks.terms) {
                    Label("Términos de uso", systemImage: "doc.text")
                }
            } header: {
                Text("Privacidad y anuncios")
            } footer: {
                Text("Personal Limits es gratis y se financia con un banner discreto. Tus tokens y lecturas nunca salen del dispositivo salvo hacia la API de cada proveedor.")
            }

            Section {
                Link(destination: StoreLinks.website) {
                    Label("Sitio web", systemImage: "globe")
                }
                Link(destination: StoreLinks.support) {
                    Label("Soporte y preguntas frecuentes", systemImage: "questionmark.circle")
                }
                LabeledContent("Versión", value: Bundle.main.versionText)
                Text("No está afiliada a Anthropic ni a OpenAI. Usa endpoints no documentados de Claude Code y Codex CLI que pueden cambiar sin previo aviso.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Acerca de")
            }
        }
        .navigationTitle("Ajustes")
        .sheet(isPresented: $showImport) {
            ManualImportView()
                .environment(store)
        }
        .alert("No se pudo conectar", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "¿Desconectar \(providerToDisconnect?.displayName ?? "")?",
            isPresented: Binding(
                get: { providerToDisconnect != nil },
                set: { if !$0 { providerToDisconnect = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Desconectar", role: .destructive) {
                if let provider = providerToDisconnect { store.disconnect(provider) }
            }
        } message: {
            Text("Se borrará el token del llavero y los datos en caché de este proveedor.")
        }
    }

    private func connect(_ provider: ProviderID) {
        busyProvider = provider
        Task {
            defer { busyProvider = nil }
            do {
                try await signIn.signIn(ProviderRegistry.provider(for: provider))
                await store.refresh()
            } catch {
                if !ProviderSignIn.isCancellation(error) {
                    errorMessage = error.localizedDescription
                }
            }
            store.reloadFromCache()
        }
    }
}

struct ProviderRow: View {
    @Environment(UsageStore.self) private var store
    let provider: ProviderID
    let isBusy: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    private var status: String {
        guard let connection = store.connections[provider] else { return "No conectado" }
        var parts = ["Conectado"]
        if let label = connection.label { parts.append(label) }
        if connection.source == .manual { parts.append("token pegado") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.body.weight(.semibold))
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isBusy {
                ProgressView()
            } else if store.connections[provider] != nil {
                Button("Desconectar", role: .destructive, action: onDisconnect)
                    .buttonStyle(.bordered)
            } else {
                Button("Conectar", action: onConnect)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

extension Bundle {
    var versionText: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
