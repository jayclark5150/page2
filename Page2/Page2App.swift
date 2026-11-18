import SwiftUI
import SwiftData

@main
struct Page2App: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .frame(minWidth: 820, minHeight: 520)
        }
        .modelContainer(for: [Source.self, Article.self, Story.self])
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            // Refresh and section navigation from the menu bar, with shortcuts.
            CommandGroup(after: .sidebar) {
                Button("Refresh") { coordinator.requestRefresh() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Stories") { coordinator.select(.stories) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Blindspot") { coordinator.select(.blindspot) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Sources") { coordinator.select(.sources) }
                    .keyboardShortcut("3", modifiers: .command)
                Divider()
            }
        }

        Settings {
            SettingsView()
        }
    }
}
