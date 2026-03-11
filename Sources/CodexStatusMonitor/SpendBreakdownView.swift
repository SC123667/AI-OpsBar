import SwiftUI

struct SpendBreakdownView: View {
    let snapshot: SpendSnapshot
    var accent: Color = .green
    var compact = false

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: compact ? 6 : 8),
            GridItem(.flexible(), spacing: compact ? 6 : 8),
        ]
    }

    var body: some View {
        if snapshot.hasWindowBreakdown {
            LazyVGrid(columns: columns, alignment: .leading, spacing: compact ? 6 : 8) {
                ForEach(snapshot.availableWindows) { window in
                    if let value = snapshot.formattedValue(for: window) {
                        SpendBreakdownTile(
                            title: window.title,
                            value: value,
                            accent: accent,
                            compact: compact
                        )
                    }
                }
            }
        } else {
            Text(snapshot.compactText)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SpendBreakdownTile: View {
    let title: String
    let value: String
    let accent: Color
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            Text(title)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(compact ? .caption.monospacedDigit() : .subheadline.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 7 : 9)
        .background(accent.opacity(compact ? 0.08 : 0.1), in: RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .stroke(accent.opacity(compact ? 0.14 : 0.18), lineWidth: 1)
        )
    }
}
