import SwiftUI
import SwiftData

/// Lists outlets with an enable toggle and the last fetched time.
/// Toggling isEnabled persists through SwiftData autosave.
struct SourcesView: View {
    @Query(sort: \Source.name) private var sources: [Source]

    var body: some View {
        Group {
            if sources.isEmpty {
                ContentUnavailableView(
                    "No sources",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("The starter list seeds on first launch.")
                )
            } else {
                List {
                    ForEach(sources) { source in
                        SourceRow(source: source)
                    }
                }
            }
        }
        .navigationTitle("Sources")
    }
}

private struct SourceRow: View {
    @Bindable var source: Source

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(source.name).font(.body.weight(.medium))
                    BiasChip(bias: source.bias)
                }
                Text(lastFetchedText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Enabled", isOn: $source.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }

    private var lastFetchedText: String {
        guard let date = source.lastFetchedAt else { return "Never fetched" }
        return "Last fetched \(date.formatted(.relative(presentation: .named)))"
    }
}
