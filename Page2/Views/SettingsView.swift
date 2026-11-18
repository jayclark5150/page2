import SwiftUI

/// The Settings window. Values write straight to UserDefaults through AppStorage,
/// which AppSettings.current reads at the next refresh.
struct SettingsView: View {
    @AppStorage(SettingsKeys.refreshIntervalMinutes) private var refreshInterval = 30
    @AppStorage(SettingsKeys.clusterThreshold) private var clusterThreshold = 0.35
    @AppStorage(SettingsKeys.articleAgeDays) private var articleAgeDays = 7

    var body: some View {
        Form {
            Section("Refresh") {
                Stepper("Every \(refreshInterval) minutes",
                        value: $refreshInterval, in: 5...240, step: 5)
                Text("Also refreshes on launch.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Clustering") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Similarity threshold: \(clusterThreshold, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $clusterThreshold, in: 0.10...0.90, step: 0.05)
                    Text("Higher groups fewer articles together, lower groups more.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Articles") {
                Stepper("Keep the last \(articleAgeDays) days",
                        value: $articleAgeDays, in: 1...30)
                Text("Older articles are dropped on refresh.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 400)
        .scenePadding()
        #endif
    }
}

#Preview {
    SettingsView()
}
