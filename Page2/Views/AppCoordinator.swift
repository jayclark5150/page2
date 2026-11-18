import Foundation
import Observation

/// Shared window state so menu commands can drive the UI. Holds the sidebar
/// selection (restored across launches) and a refresh request token.
@MainActor
@Observable
final class AppCoordinator {
    var selection: SidebarItem? {
        didSet {
            if let selection {
                UserDefaults.standard.set(selection.rawValue, forKey: SettingsKeys.lastSection)
            }
        }
    }

    /// Incremented to ask the main view to refresh. The view watches this.
    private(set) var refreshToken = 0

    init() {
        let saved = UserDefaults.standard.string(forKey: SettingsKeys.lastSection)
        selection = saved.flatMap(SidebarItem.init(rawValue:)) ?? .stories
    }

    func requestRefresh() {
        refreshToken += 1
    }

    func select(_ item: SidebarItem) {
        selection = item
    }
}
