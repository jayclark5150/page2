import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppCoordinator.self) private var coordinator
    @State private var refresher = FeedRefresher()
    @State private var didSeed = false
    @State private var showingSettings = false

    var body: some View {
        @Bindable var coordinator = coordinator

        NavigationSplitView {
            List(SidebarItem.allCases, selection: $coordinator.selection) { item in
                Label(item.title, systemImage: item.systemImage).tag(Optional(item))
            }
            .navigationTitle("Page 2")
            .frame(minWidth: 180)
        } detail: {
            detail(for: coordinator.selection ?? .stories)
                .safeAreaInset(edge: .bottom) { errorBar }
                .toolbar {
                    ToolbarItem(placement: statusPlacement) { progressStatus }
                    ToolbarItem(placement: .primaryAction) { refreshButton }
                    #if os(iOS)
                    ToolbarItem(placement: .primaryAction) { settingsButton }
                    #endif
                }
        }
        .task { await startup() }
        .onChange(of: coordinator.refreshToken) {
            Task { await refresher.refresh(context: modelContext) }
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
        #endif
    }

    private var statusPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .status
        #else
        .automatic
        #endif
    }

    #if os(iOS)
    private var settingsButton: some View {
        Button { showingSettings = true } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
    #endif

    @ViewBuilder
    private func detail(for item: SidebarItem) -> some View {
        switch item {
        case .stories: StoriesView()
        case .blindspot: BlindspotView()
        case .sources: SourcesView()
        }
    }

    // MARK: Toolbar

    @ViewBuilder
    private var progressStatus: some View {
        if refresher.isRefreshing, refresher.progressTotal > 0 {
            HStack(spacing: 6) {
                ProgressView(value: Double(refresher.progressCompleted),
                             total: Double(refresher.progressTotal))
                    .frame(width: 90)
                Text("\(refresher.progressCompleted)/\(refresher.progressTotal)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
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

    // MARK: Error state

    @ViewBuilder
    private var errorBar: some View {
        if let message = topError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message).font(.caption).lineLimit(2)
                Spacer()
            }
            .padding(8)
            .background(.ultraThinMaterial)
        }
    }

    private var topError: String? {
        if let error = refresher.lastError { return error }
        if refresher.hasSourceErrors {
            let count = refresher.sourceErrors.count
            return count == 1 ? "1 source failed to load" : "\(count) sources failed to load"
        }
        return nil
    }

    // MARK: Lifecycle

    private func startup() async {
        seedIfNeeded()
        guard !isRunningTests else { return }

        await refresher.refresh(context: modelContext)

        // Periodic refresh. Reads the interval each cycle so Settings changes
        // take effect on the next tick.
        while !Task.isCancelled {
            let minutes = max(5, AppSettings.current.refreshIntervalMinutes)
            try? await Task.sleep(for: .seconds(Double(minutes) * 60))
            if Task.isCancelled { break }
            await refresher.refresh(context: modelContext)
        }
    }

    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        do {
            try SourceSeeder().seed(into: modelContext)
        } catch {
            print("Page2 seed failed: \(error)")
        }
    }

    /// Avoids kicking off network during unit test runs that host this app.
    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }
}

#Preview {
    ContentView()
        .environment(AppCoordinator())
        .modelContainer(for: [Source.self, Article.self, Story.self], inMemory: true)
}
