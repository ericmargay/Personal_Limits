import SwiftUI

struct DashboardView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.cards.isEmpty {
                    ContentUnavailableView {
                        Label("Sin proveedores", systemImage: "gauge.with.dots.needle.33percent")
                    } description: {
                        Text("Conecta Claude o Codex en Ajustes para ver tus límites aquí y en el widget.")
                    } actions: {
                        NavigationLink("Abrir ajustes") { SettingsView() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(store.cards) { card in
                                ProviderCardView(card: card)
                            }
                            footer
                        }
                        .padding()
                        // En iPad las tarjetas no se estiran a todo el ancho.
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(.systemGroupedBackground))
                    .refreshable { await store.refresh() }
                }
            }
            .navigationTitle("Límites")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Actualizar")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Ajustes")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdBannerSlot()
            }
        }
        .task { await store.refreshIfStale() }
    }

    @ViewBuilder
    private var footer: some View {
        if let last = store.lastRefresh {
            (Text("Actualizado hace ") + Text(last, style: .relative))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
}

#Preview {
    DashboardView()
        .environment(UsageStore())
        .environment(AdsManager())
}
