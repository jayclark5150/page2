import Foundation

/// The top level sections shown in the sidebar.
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case stories
    case blindspot
    case sources

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stories: return "Stories"
        case .blindspot: return "Blindspot"
        case .sources: return "Sources"
        }
    }

    var systemImage: String {
        switch self {
        case .stories: return "newspaper"
        case .blindspot: return "eye.trianglebadge.exclamationmark"
        case .sources: return "antenna.radiowaves.left.and.right"
        }
    }
}
