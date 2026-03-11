import SwiftUI

struct HistorySparkline: View {
    let samples: [ServiceHistorySample]
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let points = Array(samples.suffix(12))
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let step = width / CGFloat(max(points.count, 1))

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color(for: sample))
                        .frame(
                            width: max(step - 3, 4),
                            height: barHeight(for: sample, maxHeight: height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private func barHeight(for sample: ServiceHistorySample, maxHeight: CGFloat) -> CGFloat {
        let base: CGFloat
        switch sample.state {
        case .pass:
            base = 0.45
        case .warning:
            base = 0.72
        case .fail:
            base = 1
        }

        return max(5, maxHeight * base)
    }

    private func color(for sample: ServiceHistorySample) -> Color {
        switch sample.state {
        case .pass:
            return tint.opacity(0.55)
        case .warning:
            return Color.orange
        case .fail:
            return Color.red
        }
    }
}
