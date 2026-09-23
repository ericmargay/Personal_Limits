import SwiftUI
import WidgetKit

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let usages: [ProviderUsage]
}

/// Las complicaciones leen la caché que el iPhone sincroniza vía WatchConnectivity.
struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), usages: DemoData.usages)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let cached = Self.cachedUsages()
        completion(ComplicationEntry(date: Date(), usages: (cached.isEmpty || context.isPreview) ? DemoData.usages : cached))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: Date(), usages: Self.cachedUsages())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }

    static func cachedUsages() -> [ProviderUsage] {
        let all = UsageCache.loadAll()
        return ProviderID.allCases.compactMap { all[$0] }
    }
}

struct LimitsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PersonalLimitsComplication", provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Límites de IA")
        .description("Uso de Claude y Codex sincronizado desde el iPhone.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry

    /// Proveedor con la sesión más consumida: lo que más urge ver.
    private var featured: (ProviderUsage, UsageWindow)? {
        let pairs = entry.usages.compactMap { usage in usage.primary.map { (usage, $0) } }
        return pairs.max { $0.1.clampedPercent < $1.1.clampedPercent }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            if let (usage, window) = featured {
                Gauge(value: window.fraction) {
                    Image(systemName: usage.provider.symbolName)
                } currentValueLabel: {
                    Text("\(Int(window.clampedPercent.rounded()))")
                        .font(.system(.body, design: .rounded).weight(.bold))
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                Image(systemName: "gauge.with.dots.needle.0percent")
            }
        case .accessoryCorner:
            if let (usage, window) = featured {
                Text(UsageStyle.percentText(window.percent))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .widgetCurvesContent()
                    .widgetLabel {
                        Gauge(value: window.fraction) {
                            Text(usage.provider.displayName)
                        }
                        .gaugeStyle(.accessoryLinearCapacity)
                    }
            } else {
                Text("—")
            }
        case .accessoryInline:
            let parts = entry.usages.compactMap { usage -> String? in
                guard let primary = usage.primary else { return nil }
                return "\(usage.provider.displayName) \(UsageStyle.percentText(primary.percent))"
            }
            Text(parts.isEmpty ? "Sin datos" : parts.joined(separator: " · "))
        default:
            VStack(alignment: .leading, spacing: 3) {
                ForEach(entry.usages.prefix(2)) { usage in
                    HStack(spacing: 4) {
                        Text(usage.provider.displayName).font(.caption.weight(.bold))
                        if let primary = usage.primary {
                            Text(UsageStyle.percentText(primary.percent))
                                .font(.caption.weight(.semibold).monospacedDigit())
                        }
                        if let secondary = usage.secondary {
                            Text("· \(secondary.label.lowercased()) \(UsageStyle.percentText(secondary.percent))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    if let primary = usage.primary {
                        ProgressView(value: primary.fraction)
                    }
                }
                if entry.usages.isEmpty {
                    Text("Abre Personal Limits en el iPhone").font(.caption2)
                }
            }
            .widgetAccentable()
        }
    }
}
