import AppIntents
import SwiftUI
import WidgetKit

// MARK: Configuración

enum ProviderChoice: String, AppEnum {
    case all
    case claude
    case codex

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Proveedor"
    static var caseDisplayRepresentations: [ProviderChoice: DisplayRepresentation] = [
        .all: "Todos",
        .claude: "Claude",
        .codex: "Codex",
    ]

    func filter(_ usages: [ProviderUsage]) -> [ProviderUsage] {
        switch self {
        case .all: return usages
        case .claude: return usages.filter { $0.provider == .claude }
        case .codex: return usages.filter { $0.provider == .codex }
        }
    }
}

struct LimitsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Límites"
    static var description = IntentDescription("Elige qué proveedor mostrar.")

    @Parameter(title: "Proveedor", default: .all)
    var provider: ProviderChoice
}

// MARK: Timeline

struct LimitsEntry: TimelineEntry {
    let date: Date
    let usages: [ProviderUsage]
    let choice: ProviderChoice
}

struct LimitsTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LimitsEntry {
        LimitsEntry(date: Date(), usages: DemoData.usages, choice: .all)
    }

    func snapshot(for configuration: LimitsWidgetIntent, in context: Context) async -> LimitsEntry {
        let cached = Self.cachedUsages()
        let usages = (cached.isEmpty || context.isPreview) ? DemoData.usages : cached
        return LimitsEntry(date: Date(), usages: usages, choice: configuration.provider)
    }

    func timeline(for configuration: LimitsWidgetIntent, in context: Context) async -> Timeline<LimitsEntry> {
        // El widget consulta la red por su cuenta y renueva tokens si hace falta;
        // OAuthClient serializa la renovación con la app mediante un bloqueo de
        // fichero, así que no hay carreras con la rotación de refresh tokens.
        if !CredentialStore.connectedProviders.isEmpty {
            await withTimeout(seconds: 20) {
                await UsageRefresher.refreshAll(allowTokenRefresh: true, reloadWidgets: false)
            }
        }
        // WidgetKit concede ~40-70 recargas al día a un widget visible: pedir
        // 15 min significa en la práctica una lectura nueva cada 15-30 min.
        let entry = LimitsEntry(date: Date(), usages: Self.cachedUsages(), choice: configuration.provider)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    static func cachedUsages() -> [ProviderUsage] {
        let all = UsageCache.loadAll()
        return ProviderID.allCases.compactMap { all[$0] }
    }
}

/// Ejecuta `operation` y vuelve como muy tarde a los `seconds` segundos.
private func withTimeout(seconds: TimeInterval, _ operation: @escaping @Sendable () async -> Void) async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask { await operation() }
        group.addTask { try? await Task.sleep(for: .seconds(seconds)) }
        await group.next()
        group.cancelAll()
    }
}

// MARK: Widget

struct PersonalLimitsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: AppConfig.widgetKind,
                               intent: LimitsWidgetIntent.self,
                               provider: LimitsTimelineProvider()) { entry in
            LimitsWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Límites de IA")
        .description("Uso de Claude y Codex con cuenta atrás hasta el reinicio.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview("Pequeño", as: .systemSmall) {
    PersonalLimitsWidget()
} timeline: {
    LimitsEntry(date: .now, usages: DemoData.usages, choice: .all)
    LimitsEntry(date: .now, usages: DemoData.usages, choice: .claude)
}

#Preview("Mediano", as: .systemMedium) {
    PersonalLimitsWidget()
} timeline: {
    LimitsEntry(date: .now, usages: DemoData.usages, choice: .all)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    PersonalLimitsWidget()
} timeline: {
    LimitsEntry(date: .now, usages: DemoData.usages, choice: .all)
}

#Preview("Circular", as: .accessoryCircular) {
    PersonalLimitsWidget()
} timeline: {
    LimitsEntry(date: .now, usages: DemoData.usages, choice: .claude)
}

#Preview("Grande", as: .systemLarge) {
    PersonalLimitsWidget()
} timeline: {
    LimitsEntry(date: .now, usages: DemoData.usages, choice: .all)
}
