import SwiftUI

/// Placeholder until Milestone 3. Blindspot logic needs clustered stories first.
struct BlindspotView: View {
    var body: some View {
        ContentUnavailableView(
            "Blindspot",
            systemImage: "eye.trianglebadge.exclamationmark",
            description: Text("Stories that one side barely covered will appear here after clustering lands.")
        )
        .navigationTitle("Blindspot")
    }
}
