import Foundation

/// Thresholds for the Blindspot rule, kept in one place.
struct BlindspotSettings: Sendable {
    /// A story needs at least this many distinct outlets to qualify.
    var minOutlets: Int = 4
    /// A side counts as a blindspot when its share is below this fraction.
    var lowShare: Double = 0.10
    /// The opposite side must hold at least this fraction to count as dominant.
    var majorityShare: Double = 0.5
}

/// Decides whether a story is a blindspot and which side missed it.
/// Left and right are the two sides, center is treated as neutral middle.
enum BlindspotFinder {

    /// Returns the side that barely covered the story, or nil if it is not a
    /// blindspot. A result of .left means the left barely covered it.
    static func side(leftOutlets: Int,
                     centerOutlets: Int,
                     rightOutlets: Int,
                     settings: BlindspotSettings = BlindspotSettings()) -> Bias? {
        let total = leftOutlets + centerOutlets + rightOutlets
        guard total >= settings.minOutlets else { return nil }

        let leftShare = Double(leftOutlets) / Double(total)
        let rightShare = Double(rightOutlets) / Double(total)

        if leftShare < settings.lowShare, rightShare >= settings.majorityShare {
            return .left
        }
        if rightShare < settings.lowShare, leftShare >= settings.majorityShare {
            return .right
        }
        return nil
    }

    static func side(for story: Story,
                     settings: BlindspotSettings = BlindspotSettings()) -> Bias? {
        side(leftOutlets: story.outletCount(for: .left),
             centerOutlets: story.outletCount(for: .center),
             rightOutlets: story.outletCount(for: .right),
             settings: settings)
    }

    /// Label such as "Blindspot: left".
    static func label(for side: Bias) -> String {
        "Blindspot: \(side.label.lowercased())"
    }
}
