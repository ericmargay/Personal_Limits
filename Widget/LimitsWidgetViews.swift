import SwiftUI
import WidgetKit

struct LimitsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LimitsEntry

    private var usages: [ProviderUsage] { entry.choice.filter(entry.usages) }

    var body: some View {
        if usages.isEmpty {
            EmptyWidgetView(family: family)
        } else {
            switch family {
            case .systemSmall:
                SmallWidgetView(usages: usages)
            case .accessoryCircular:
                CircularWidgetView(usages: usages)
            case .accessoryRectangular:
                RectangularWidgetView(usages: usages)
            case .accessoryInline:
                InlineWidgetView(usages: usages)
            case .systemLarge:
                LargeWidgetView(usages: usages)
            case .systemExtraLarge:
                MediumWidgetView(usages: usages, maxWindows: 4)
            default:
                MediumWidgetView(usages: usages)
            }
        }
    }
}

// MARK: Piezas

struct RingView: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.002, min(fraction, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct MiniBar: View {
    let window: UsageWindow
    var showReset = false

    private var color: Color { UsageStyle.color(forPercent: window.percent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(window.label)
                    .font(.caption2.weight(.semibold))
                if showReset, let reset = window.resetsAt, reset > Date() {
                    Text(reset, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                Text(UsageStyle.percentText(window.percent))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
            }
            ProgressView(value: window.fraction)
                .tint(color)
        }
    }
}

struct ProviderHeader: View {
    let usage: ProviderUsage
    var showAccount = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: usage.provider.symbolName)
                .font(.caption.weight(.bold))
            Text(usage.provider.displayName)
                .font(.caption.weight(.bold))
            if showAccount, let plan = usage.plan {
                Text(plan)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(UsageStyle.tint(usage.provider))
    }
}

// MARK: Familias

struct SmallWidgetView: View {
    let usages: [ProviderUsage]

    var body: some View {
        if usages.count == 1, let usage = usages.first {
            single(usage)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(usages.prefix(2)) { usage in
                    VStack(alignment: .leading, spacing: 4) {
                        ProviderHeader(usage: usage)
                        if let primary = usage.primary { MiniBar(window: primary) }
                        if let secondary = usage.secondary {
                            HStack {
                                Text(secondary.label)
                                Spacer()
                                Text(UsageStyle.percentText(secondary.percent)).monospacedDigit()
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func single(_ usage: ProviderUsage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProviderHeader(usage: usage, showAccount: true)
            if let primary = usage.primary {
                HStack(spacing: 10) {
                    RingView(fraction: primary.fraction, color: UsageStyle.color(forPercent: primary.percent))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Text(UsageStyle.percentText(primary.percent))
                                .font(.caption.weight(.bold).monospacedDigit())
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary.label)
                            .font(.caption.weight(.semibold))
                        if let reset = primary.resetsAt, reset > Date() {
                            Text(reset, style: .timer)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let secondary = usage.secondary {
                MiniBar(window: secondary)
            }
        }
    }
}

struct MediumWidgetView: View {
    let usages: [ProviderUsage]
    var maxWindows = 2

    private var oldestRead: Date? { usages.map(\.fetchedAt).min() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            columns
            if let oldestRead {
                (Text("Leído hace ") + Text(oldestRead, style: .relative))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(usages.prefix(2)) { usage in
                VStack(alignment: .leading, spacing: 8) {
                    ProviderHeader(usage: usage, showAccount: true)
                    ForEach(usage.windows.prefix(maxWindows)) { window in
                        MiniBar(window: window, showReset: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct RectangularWidgetView: View {
    let usages: [ProviderUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(usages.prefix(2)) { usage in
                HStack(spacing: 4) {
                    Text(usage.provider.displayName)
                        .font(.caption.weight(.bold))
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
        }
        .widgetAccentable()
    }
}

struct CircularWidgetView: View {
    let usages: [ProviderUsage]

    private var featured: (ProviderUsage, UsageWindow)? {
        let pairs = usages.compactMap { usage in usage.primary.map { (usage, $0) } }
        return pairs.max { $0.1.clampedPercent < $1.1.clampedPercent }
    }

    var body: some View {
        if let (usage, window) = featured {
            Gauge(value: window.fraction) {
                Image(systemName: usage.provider.symbolName)
            } currentValueLabel: {
                Text("\(Int(window.clampedPercent.rounded()))")
                    .font(.system(.body, design: .rounded).weight(.bold))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        } else {
            Text("—")
        }
    }
}

struct InlineWidgetView: View {
    let usages: [ProviderUsage]

    var body: some View {
        let parts = usages.compactMap { usage -> String? in
            guard let primary = usage.primary else { return nil }
            return "\(usage.provider.displayName) \(UsageStyle.percentText(primary.percent))"
        }
        Text(parts.joined(separator: " · "))
    }
}

struct EmptyWidgetView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "gauge.with.dots.needle.0percent")
        case .accessoryInline:
            Text("Sin proveedores")
        default:
            VStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.0percent")
                    .font(.title2)
                Text("Conecta un proveedor en Personal Limits")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        }
    }
}

/// Widget grande: todos los proveedores con todas sus ventanas.
struct LargeWidgetView: View {
    let usages: [ProviderUsage]

    private var oldestRead: Date? { usages.map(\.fetchedAt).min() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(usages) { usage in
                VStack(alignment: .leading, spacing: 6) {
                    ProviderHeader(usage: usage, showAccount: true)
                    ForEach(usage.windows) { window in
                        MiniBar(window: window, showReset: true)
                    }
                }
                if usage.id != usages.last?.id {
                    Divider()
                }
            }
            Spacer(minLength: 0)
            if let oldestRead {
                (Text("Leído hace ") + Text(oldestRead, style: .relative))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
