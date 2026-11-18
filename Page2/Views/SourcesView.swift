import SwiftUI
import SwiftData

/// Lists outlets with an enable toggle and last fetched time, plus adding a
/// custom outlet, deleting one, and OPML import and export. Deleted and user
/// added choices survive the JSON seeder.
struct SourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Source> { !$0.isDeleted }, sort: \Source.name)
    private var sources: [Source]
    @State private var showingAdd = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var importSummary: String?

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
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingImporter = true } label: {
                        Label("Import from OPML", systemImage: "square.and.arrow.down")
                    }
                    Button { showingExporter = true } label: {
                        Label("Export to OPML", systemImage: "square.and.arrow.up")
                    }
                    .disabled(sources.isEmpty)
                } label: {
                    Label("Import or Export", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddSourceView() }
        }
        .fileExporter(isPresented: $showingExporter,
                      document: OPMLDocument(text: OPMLService.export(exportList)),
                      contentType: .opml,
                      defaultFilename: "Page 2 Sources") { _ in }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.opml, .xml]) { result in
            if case .success(let url) = result { importOPML(from: url) }
        }
        .alert("Import complete", isPresented: importAlertBinding) {
            Button("OK") { importSummary = nil }
        } message: {
            Text(importSummary ?? "")
        }
    }

    private var exportList: [ImportedSource] {
        sources.map {
            ImportedSource(name: $0.name, feedURL: $0.feedURLString,
                           siteURL: $0.siteURLString, bias: $0.bias, isEnabled: $0.isEnabled)
        }
    }

    private var importAlertBinding: Binding<Bool> {
        Binding(get: { importSummary != nil }, set: { if !$0 { importSummary = nil } })
    }

    /// Adds new outlets from an OPML file. Existing feeds are matched by URL and
    /// skipped, and a previously removed feed is restored. Imports are user owned.
    private func importOPML(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            importSummary = "Could not read that file."
            return
        }

        let incoming = OPMLService.parse(text)
        let existing = (try? modelContext.fetch(FetchDescriptor<Source>())) ?? []
        var byFeed: [String: Source] = [:]
        for source in existing { byFeed[source.feedURLString] = source }
        var takenSlugs = Set(existing.map(\.slug))

        var added = 0
        var restored = 0
        for item in incoming {
            if let match = byFeed[item.feedURL] {
                if match.isDeleted {
                    match.isDeleted = false
                    match.isEnabled = item.isEnabled
                    restored += 1
                }
            } else {
                let slug = Slug.unique(Slug.make(from: item.name), taken: takenSlugs)
                takenSlugs.insert(slug)
                let source = Source(slug: slug, name: item.name,
                                    feedURLString: item.feedURL, siteURLString: item.siteURL,
                                    bias: item.bias, isEnabled: item.isEnabled, isUserAdded: true)
                modelContext.insert(source)
                byFeed[item.feedURL] = source
                added += 1
            }
        }
        try? modelContext.save()

        if incoming.isEmpty {
            importSummary = "No feeds found in that file."
        } else {
            var parts = ["Added \(added)"]
            if restored > 0 { parts.append("restored \(restored)") }
            parts.append("from \(incoming.count) in the file")
            importSummary = parts.joined(separator: ", ") + "."
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
