import SwiftUI

struct WindowGaugeView: View {
    let window: UsageWindow

    private var color: Color { UsageStyle.color(forPercent: window.percent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(window.label)
                    .font(.subheadline.weight(.semibold))
                if let detail = window.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(UsageStyle.percentText(window.percent))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
            }
            ProgressView(value: window.fraction)
                .tint(color)
            HStack(spacing: 4) {
                Image(systemName: "arrow.counterclockwise")
                if let reset = window.resetsAt {
                    if reset > Date() {
                        Text("Se reinicia en ") + Text(reset, style: .relative)
                    } else {
                        Text("Reinicio pendiente")
                    }
                } else {
                    Text("Sin fecha de reinicio")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
