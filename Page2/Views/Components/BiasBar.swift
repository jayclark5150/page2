import SwiftUI

/// A three segment bar showing distinct outlet counts for left, center, right.
/// Segment widths are proportional to the counts. Empty sides are omitted.
struct BiasBar: View {
    let left: Int
    let center: Int
    let right: Int
    var width: CGFloat = 140
    var height: CGFloat = 8

    private var total: Int { max(1, left + center + right) }

    var body: some View {
        HStack(spacing: 1) {
            segment(count: left, color: Bias.left.color)
            segment(count: center, color: Bias.center.color)
            segment(count: right, color: Bias.right.color)
        }
        .frame(width: width, height: height)
        .background(Color.gray.opacity(0.12), in: Capsule())
        .clipShape(Capsule())
        .accessibilityLabel("Coverage: \(left) left, \(center) center, \(right) right")
    }

    @ViewBuilder
    private func segment(count: Int, color: Color) -> some View {
        if count > 0 {
            color.frame(width: width * CGFloat(count) / CGFloat(total))
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        BiasBar(left: 3, center: 1, right: 0)
        BiasBar(left: 1, center: 2, right: 4)
        BiasBar(left: 0, center: 0, right: 5)
    }
    .padding()
}
