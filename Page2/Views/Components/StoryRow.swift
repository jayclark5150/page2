import SwiftUI

/// A story summary row: headline, distinct outlet count, and a bias bar.
/// Optionally shows a blindspot label above the headline.
struct StoryRow: View {
    let story: Story
    var blindspotSide: Bias?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let side = blindspotSide {
                Text(BlindspotFinder.label(for: side))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(side.color)
            }

            Text(story.headline)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(outletText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let published = story.latestPublishedAt {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(published.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                BiasBar(left: story.outletCount(for: .left),
                        center: story.outletCount(for: .center),
                        right: story.outletCount(for: .right))
            }
        }
        .padding(.vertical, 4)
    }

    private var outletText: String {
        let count = story.totalOutletCount
        return count == 1 ? "1 outlet" : "\(count) outlets"
    }
}
