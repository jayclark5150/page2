import SwiftUI
import SwiftData

@main
struct Page2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Source.self, Article.self, Story.self])
    }
}
