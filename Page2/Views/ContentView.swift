import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: SidebarItem? = .stories
    @State private var refresher = FeedRefresher()
    @State private var didSeed = false

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.systemImage).tag(item)
            }
            .navigationTitle("Page 2")
            .frame(minWidth: 180)
        } detail: {
            detail
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        refreshButton
                    }
                }
        }
        .task { seedIfNeeded() }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .stories {
        case .stories: StoriesView()
        case .blindspot: BlindspotView()
        case .sources: SourcesView()
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await refresher.refresh(context: modelContext) }
        } label: {
            if refresher.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(refresher.isRefreshing)
        .help("Fetch the latest articles from enabled sources")
    }

    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        do {
            try SourceSeeder().seed(into: modelContext)
        } catch {
            // Seeding failure is not fatal. Surface it in the console for now.
            print("Page2 seed failed: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Source.self, Article.self, Story.self], inMemory: true)
}
