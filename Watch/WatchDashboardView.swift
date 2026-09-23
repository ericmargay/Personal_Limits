import SwiftUI

struct WatchDashboardView: View {
    @Environment(WatchSessionManager.self) private var session

    var body: some View {
        NavigationStack {
            Group {
                if session.usages.isEmpty {
                    ScrollView {
                        VStack(spacing: 10) {
                            Image(systemName: "iphone.and.arrow.forward")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Conecta un proveedor en el iPhone y abre allí la app una vez.")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                            Button("Pedir datos al iPhone") { session.requestRefresh() }
                            if let error = session.errorMessage {
                                Text(error).font(.footnote).foregroundStyle(.orange)
                            }
                        }
                        .padding(.top, 8)
                    }
                } else {
                    List {
                        ForEach(session.usages) { usage in
                            WatchProviderSection(usage: usage)
                        }
                        Section {
                            Button {
                                session.requestRefresh()
                            } label: {
                                if session.isRefreshing {
                                    ProgressView()
                                } else {
                                    Label("Actualizar desde iPhone", systemImage: "arrow.clockwise")
                                }
                            }
                            if let last = session.lastSync {
                                (Text("Sincronizado hace ") + Text(last, style: .relative))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            if let error = session.errorMessage {
                                Text(error).font(.footnote).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Límites")
        }
    }
}

struct WatchProviderSection: View {
    let usage: ProviderUsage

    var body: some View {
        Section {
            ForEach(usage.windows) { window in
                VStack(alignment: .leading, spacing: 4) {
                    Gauge(value: window.fraction) {
                        Text(window.label)
                    } currentValueLabel: {
                        Text(UsageStyle.percentText(window.percent))
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(UsageStyle.color(forPercent: window.percent))
                    if let reset = window.resetsAt, reset > Date() {
                        (Text("Reinicio en ") + Text(reset, style: .relative))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Label(usage.provider.displayName, systemImage: usage.provider.symbolName)
                .foregroundStyle(UsageStyle.tint(usage.provider))
        }
    }
}
