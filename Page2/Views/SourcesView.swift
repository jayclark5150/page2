import SwiftUI
import SwiftData

/// Lists outlets with an enable toggle and last fetched time, plus adding a
/// custom outlet and deleting one. Deleted and user added choices survive the
/// JSON seeder.
struct SourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Source> { !$0.isDeleted }, sort: \Source.name)
    private var sources: [Source]
    @State private var showingAdd = false

    var body: some View {
        Group {
            if sources.isEmpty {
                ContentUnavailableView(
                    "No sources",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Add an outlet with the plus button, or refresh to seed the starter list.")
                )
            } else {
                List {
                    ForEach(sources) { source in
                        SourceRow(source: source)
                            .contextMenu {
                                Button(role: .destructive) { delete(source) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(source) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Sources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Label("Add Source", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddSourceView() }
        }
    }

    /// User added outlets are removed outright. Seeded outlets are tombstoned so
    /// the seeder does not add them back on the next launch.
    private func delete(_ source: Source) {
        if source.isUserAdded {
            modelContext.delete(source)
        } else {
            source.isDeleted = true
            source.isEnabled = false
        }
        try? modelContext.save()
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
                    if source.isUserAdded {
                        Text("Added")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
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
