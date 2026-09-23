import SwiftUI

struct ProviderCardView: View {
    let card: UsageStore.Card

    private var tint: Color { UsageStyle.tint(card.provider) }

    private var subtitle: String {
        [card.provider.vendorName, card.usage?.account].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.18))
                    Image(systemName: card.provider.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.provider.displayName)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let plan = card.usage?.plan {
                    Text(plan)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tint.opacity(0.15)))
                        .foregroundStyle(tint)
                }
            }

            if let usage = card.usage {
                ForEach(usage.windows) { window in
                    WindowGaugeView(window: window)
                }
                (Text("Leído hace ") + Text(usage.fetchedAt, style: .relative))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if card.error == nil {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Obteniendo datos…")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }

            if let error = card.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ProviderCardView(card: .init(provider: .claude, usage: DemoData.usages[0], error: nil))
            ProviderCardView(card: .init(provider: .codex, usage: nil, error: "La sesión caducó."))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
