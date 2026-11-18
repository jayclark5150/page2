import SwiftUI

/// A small colored capsule showing an outlet's bias.
struct BiasChip: View {
    let bias: Bias

    var body: some View {
        Text(bias.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel("Bias \(bias.label)")
    }

    private var color: Color {
        switch bias {
        case .left: return .blue
        case .center: return .purple
        case .right: return .red
        }
    }
}

extension Bias {
    /// Shared color so chips and bias bars match.
    var color: Color {
        switch self {
        case .left: return .blue
        case .center: return .purple
        case .right: return .red
        }
    }
}

#Preview {
    HStack { ForEach(Bias.allCases) { BiasChip(bias: $0) } }.padding()
}
