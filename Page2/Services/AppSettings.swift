import Foundation

/// UserDefaults keys shared between the Settings UI and the services that read them.
enum SettingsKeys {
    static let refreshIntervalMinutes = "refreshIntervalMinutes"
    static let clusterThreshold = "clusterThreshold"
    static let articleAgeDays = "articleAgeDays"
    static let lastSection = "lastSection"
}

/// A snapshot of user settings read from UserDefaults, with defaults applied.
struct AppSettings: Sendable {
    var refreshIntervalMinutes: Int
    var clusterThreshold: Double
    var articleAgeDays: Int

    static let fallback = AppSettings(refreshIntervalMinutes: 30,
                                      clusterThreshold: 0.35,
                                      articleAgeDays: 7)

    static var current: AppSettings {
        let defaults = UserDefaults.standard
        return AppSettings(
            refreshIntervalMinutes: defaults.object(forKey: SettingsKeys.refreshIntervalMinutes) as? Int
                ?? fallback.refreshIntervalMinutes,
            clusterThreshold: defaults.object(forKey: SettingsKeys.clusterThreshold) as? Double
                ?? fallback.clusterThreshold,
            articleAgeDays: defaults.object(forKey: SettingsKeys.articleAgeDays) as? Int
                ?? fallback.articleAgeDays
        )
    }
}
