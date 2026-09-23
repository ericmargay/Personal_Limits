import SwiftUI

/// Importa tokens copiados desde otro equipo (portapapeles universal, AirDrop…).
struct ManualImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UsageStore.self) private var store
    @State private var text = ""
    @State private var isWorking = false
    @State private var message: String?

    private let help = """
    Acepta:
    • Claude: el contenido de ~/.claude/.credentials.json o solo el accessToken (sk-ant-oat01-…). Caduca en ~8 h.
    • Codex: el contenido de ~/.codex/auth.json.

    Los tokens pegados no se renuevan desde el iPhone para no invalidar los del Mac. Para uso continuo, mejor "Conectar" con inicio de sesión.
    """

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 140)
                    Button {
                        text = UIPasteboard.general.string ?? ""
                    } label: {
                        Label("Pegar del portapapeles", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("Credenciales")
                } footer: {
                    Text(help)
                }
                if let message {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Importar credenciales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Importar") { importText() }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func importText() {
        isWorking = true
        message = nil
        Task {
            defer { isWorking = false }
            do {
                let imported = try CredentialImporter.parse(text)
                CredentialStore.save(imported.credential, for: imported.provider)
                await store.refresh()
                if let error = UsageCache.errors()[imported.provider] {
                    store.disconnect(imported.provider)
                    message = error
                } else {
                    dismiss()
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }
}
